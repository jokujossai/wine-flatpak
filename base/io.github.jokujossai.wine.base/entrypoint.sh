#!/bin/bash
# Universal Wine game entrypoint with zenity dialogs
# Configured via /app/config.ini

set -e

# Handle --help argument
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    cat <<EOF
Wine Game Entrypoint

Usage: entrypoint.sh [OPTIONS]

Options:
  --help, -h    Show this help message
  --reset       Remove Wine prefix and start fresh (runs backup first if available)

Environment variables:
  USE_GAMESCOPE     Enable/disable gamescope (0 or 1, default: from config or 1)
  OUTPUT_WIDTH      Output resolution width (overrides config.ini)
  OUTPUT_HEIGHT     Output resolution height (overrides config.ini)
  FULLSCREEN        Enable fullscreen mode (0 or 1, default: from config or 0)
  WINE_VERSION      Wine version to use (default: wine-10)
  WINEARCH          Wine architecture (win32/win64/wow64)
  WINEDEBUG         Wine debug flags

Configuration:
  Game settings are read from /app/config.ini

  Config options:
    exe=<path>              Path to game executable (required)
    installer=<path>        Path to bundled installer for first-run setup
    installer_filter=<glob> File filter for user-selected installer (e.g., *.exe)
    installer_cdrom=<path>  Installer path relative to CD-ROM directory (e.g., SETUP.EXE)
    windows_version=<ver>   Windows version (e.g., winxp, win7, win10)
    output_width=<int>      Output resolution width
    output_height=<int>     Output resolution height
    use_gamescope=<0|1>     Enable gamescope (default: 1)
    fullscreen=<0|1>        Enable fullscreen mode (default: 0)

Extensions:
  Extensions installed to /app/share/wine/extensions/ are automatically
  symlinked to C:\\extensions\\ in the Wine prefix. For example, DxWnd
  is available at C:\\extensions\\dxwnd\\ if the extension is enabled.

Examples:
  # Run with gamescope disabled
  USE_GAMESCOPE=0 flatpak run <app-id>

  # Run in fullscreen mode
  FULLSCREEN=1 flatpak run <app-id>

  # Reset Wine prefix (removes all game data, keeps saves if backup script exists)
  flatpak run <app-id> --reset

  # Debug Wine issues
  flatpak run --env=WINEDEBUG=+all <app-id>
EOF
    exit 0
fi

# Handle --reset argument to remove Wine prefix and start fresh
if [ "$1" = "--reset" ]; then
    shift
    if [ -d "$WINEPREFIX" ]; then
        # Run optional backup script before removing prefix
        if [ -x "/app/bin/wine-backup.sh" ]; then
            echo "Running backup script..."
            /app/bin/wine-backup.sh
        fi
        echo "Removing Wine prefix: $WINEPREFIX"
        rm -rf "$WINEPREFIX"
        echo "Wine prefix removed. Starting fresh..."
    fi
fi

CONFIG_FILE="/app/config.ini"

# Read config.ini
if [ ! -f "$CONFIG_FILE" ]; then
    zenity --error --text="Virhe: Asetustiedostoa ei löydy ($CONFIG_FILE)" --width=400
    exit 1
fi

# Parse config.ini (required: exe, optional: installer, output_width, output_height, windows_version, use_gamescope, fullscreen)
# Environment variables override config values
EXE=$(grep -E "^exe=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '\r')
INSTALLER=$(grep -E "^installer=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '\r')
WINDOWS_VERSION=$(grep -E "^windows_version=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '\r')
INSTALLER_FILTER=$(grep -E "^installer_filter=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '\r')
INSTALLER_CDROM=$(grep -E "^installer_cdrom=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '\r')

# These can be overridden by environment variables
_CFG_OUTPUT_WIDTH=$(grep -E "^output_width=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '\r')
_CFG_OUTPUT_HEIGHT=$(grep -E "^output_height=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '\r')
_CFG_USE_GAMESCOPE=$(grep -E "^use_gamescope=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '\r')
_CFG_FULLSCREEN=$(grep -E "^fullscreen=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '\r')

# Environment overrides config, then apply defaults
OUTPUT_WIDTH="${OUTPUT_WIDTH:-$_CFG_OUTPUT_WIDTH}"
OUTPUT_HEIGHT="${OUTPUT_HEIGHT:-$_CFG_OUTPUT_HEIGHT}"
USE_GAMESCOPE="${USE_GAMESCOPE:-${_CFG_USE_GAMESCOPE:-1}}"
FULLSCREEN="${FULLSCREEN:-${_CFG_FULLSCREEN:-0}}"

export OUTPUT_WIDTH OUTPUT_HEIGHT USE_GAMESCOPE FULLSCREEN

# Initialize Wine prefix on first run
if [ ! -d "$WINEPREFIX" ]; then
    echo "Initializing Wine prefix..."
    wineboot --init

    # Set Windows version if specified in config.ini
    if [ -n "$WINDOWS_VERSION" ]; then
        if command -v winetricks &> /dev/null; then
            echo "Setting Windows version to: $WINDOWS_VERSION"
            winetricks -q "$WINDOWS_VERSION"
        else
            echo "WARNING: winetricks not available, cannot set Windows version to $WINDOWS_VERSION" >&2
            zenity --warning \
                --title="Varoitus" \
                --text="Winetricks-ohjelmaa ei löydy.\n\nWindows-versiota '$WINDOWS_VERSION' ei voitu asettaa.\n\nPeli saattaa toimia väärin." \
                --width=400
        fi
    fi

    # Run optional restore script after prefix creation
    if [ -x "/app/bin/wine-restore.sh" ]; then
        echo "Running restore script..."
        /app/bin/wine-restore.sh
    fi

    echo "Wine prefix initialized at $WINEPREFIX"
fi

# Setup D: drive if iso_contents exists
if [ -d "/app/extra/iso_contents" ]; then
    D_DRIVE="$WINEPREFIX/dosdevices/d:"
    if [ ! -e "$D_DRIVE" ]; then
        ln -sf "/app/extra/iso_contents" "$D_DRIVE"
        # Set D: as CD-ROM drive in registry
        wine reg add 'HKEY_LOCAL_MACHINE\Software\Wine\Drives' /v D: /t REG_SZ /d cdrom /f 2>/dev/null || true
    fi
fi

# Symlink extensions directory to Wine prefix
# Makes extensions available at C:\extensions\<name> in Wine
if [ -d "/app/share/wine/extensions" ]; then
    target="$WINEPREFIX/drive_c/extensions"
    if [ ! -e "$target" ]; then
        ln -sf "/app/share/wine/extensions" "$target"
    fi
fi

# Check if game executable exists
if [ -n "$EXE" ] && [ -f "$EXE" ]; then
    # Game is installed, launch it
    if [ -n "$OUTPUT_WIDTH" ] && [ -n "$OUTPUT_HEIGHT" ]; then
        exec wine-desktop -W "$OUTPUT_WIDTH" -H "$OUTPUT_HEIGHT" -- "$EXE" "$@"
    else
        exec wine-desktop -- "$EXE" "$@"
    fi
fi

# Function to run installer
run_installer() {
    local installer_path="$1"

    # Show pre-installation instructions
    zenity --info \
        --title="Pelin asennus" \
        --text="Peli asennetaan nyt.\n\n<b>TÄRKEÄÄ:</b>\n• Käytä oletushakemistoa asennuksessa\n• ÄLÄ käynnistä peliä asennuksen jälkeen\n• Sulje asennusohjelma kun asennus on valmis" \
        --width=500

    echo "Running installer: $installer_path"
    if [ -n "$OUTPUT_WIDTH" ] && [ -n "$OUTPUT_HEIGHT" ]; then
        wine explorer.exe /desktop=installer,"${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}" "$installer_path"
    else
        wine "$installer_path"
    fi
}

# Game not installed - determine installation method
INSTALLER_PATH=""

# Case 1: Bundled installer path specified
if [ -n "$INSTALLER" ]; then
    if [ ! -f "$INSTALLER" ]; then
        zenity --error \
            --title="Virhe" \
            --text="Asennusohjelmaa ei löydy:\n$INSTALLER\n\nPeliä ei ole asennettu." \
            --width=400
        exit 1
    fi
    INSTALLER_PATH="$INSTALLER"

# Case 2: User selects installer file
elif [ -n "$INSTALLER_FILTER" ]; then
    zenity --info \
        --title="Pelin asennus" \
        --text="Peliä ei ole asennettu.\n\nValitse asennusohjelman tiedosto seuraavassa ikkunassa." \
        --width=400

    INSTALLER_PATH=$(zenity --file-selection \
        --title="Valitse asennusohjelma" \
        --file-filter="Asennusohjelma | $INSTALLER_FILTER" \
        2>/dev/null) || true

    if [ -z "$INSTALLER_PATH" ]; then
        zenity --error \
            --title="Virhe" \
            --text="Asennusta ei valittu.\n\nPeliä ei asennettu." \
            --width=400
        exit 1
    fi

# Case 3: User selects CD-ROM/installation directory
elif [ -n "$INSTALLER_CDROM" ]; then
    zenity --info \
        --title="Pelin asennus" \
        --text="Peliä ei ole asennettu.\n\nValitse pelin CD-ROM tai asennushakemisto seuraavassa ikkunassa." \
        --width=400

    CDROM_DIR=$(zenity --file-selection \
        --title="Valitse asennushakemisto" \
        --directory \
        2>/dev/null) || true

    if [ -z "$CDROM_DIR" ]; then
        zenity --error \
            --title="Virhe" \
            --text="Hakemistoa ei valittu.\n\nPeliä ei asennettu." \
            --width=400
        exit 1
    fi

    INSTALLER_PATH="$CDROM_DIR/$INSTALLER_CDROM"

    if [ ! -f "$INSTALLER_PATH" ]; then
        zenity --error \
            --title="Virhe" \
            --text="Asennusohjelmaa ei löydy hakemistosta:\n$INSTALLER_PATH\n\nTarkista että valitsit oikean hakemiston." \
            --width=500
        exit 1
    fi

# Case 4: No installation method configured
else
    zenity --error \
        --title="Virhe" \
        --text="Asennusohjelmaa ei ole määritelty eikä peliä ole asennettu.\n\nTarkista config.ini-tiedosto." \
        --width=400
    exit 1
fi

# Run the installer
run_installer "$INSTALLER_PATH"

# Verify installation
if [ -n "$EXE" ] && [ -f "$EXE" ]; then
    zenity --info \
        --title="Asennus valmis" \
        --text="Peli asennettu onnistuneesti!\n\nPeli käynnistyy nyt." \
        --width=400

    # Launch game
    if [ -n "$OUTPUT_WIDTH" ] && [ -n "$OUTPUT_HEIGHT" ]; then
        exec wine-desktop -W "$OUTPUT_WIDTH" -H "$OUTPUT_HEIGHT" -- "$EXE" "$@"
    else
        exec wine-desktop -- "$EXE" "$@"
    fi
else
    zenity --error \
        --title="Asennusvirhe" \
        --text="Peliä ei löytynyt asennuksen jälkeen.\n\nOdotettu sijainti:\n$EXE\n\nTarkista että käytit oletushakemistoa asennuksessa." \
        --width=500
    exit 1
fi
