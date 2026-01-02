#!/bin/bash
# Universal Wine game entrypoint with zenity dialogs
# Configured via /app/config.ini

set -e

# Handle --reset argument to remove Wine prefix and start fresh
if [ "$1" = "--reset" ]; then
    shift
    if [ -d "$WINEPREFIX" ]; then
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

# Check if game executable exists
if [ -n "$EXE" ] && [ -f "$EXE" ]; then
    # Game is installed, launch it
    if [ -n "$OUTPUT_WIDTH" ] && [ -n "$OUTPUT_HEIGHT" ]; then
        exec wine-desktop -W "$OUTPUT_WIDTH" -H "$OUTPUT_HEIGHT" -- "$EXE" "$@"
    else
        exec wine-desktop -- "$EXE" "$@"
    fi
fi

# Game not installed - check for installer
if [ -z "$INSTALLER" ]; then
    zenity --error \
        --title="Virhe" \
        --text="Asennusohjelmaa ei ole määritelty eikä peliä ole asennettu.\n\nTarkista config.ini-tiedosto." \
        --width=400
    exit 1
fi

if [ ! -f "$INSTALLER" ]; then
    zenity --error \
        --title="Virhe" \
        --text="Asennusohjelmaa ei löydy:\n$INSTALLER\n\nPeliä ei ole asennettu." \
        --width=400
    exit 1
fi

# Show pre-installation instructions
zenity --info \
    --title="Pelin asennus" \
    --text="Peli asennetaan nyt.\n\n<b>TÄRKEÄÄ:</b>\n• Käytä oletushakemistoa asennuksessa\n• ÄLÄ käynnistä peliä asennuksen jälkeen\n• Sulje asennusohjelma kun asennus on valmis" \
    --width=500

# Run installer
echo "Running installer: $INSTALLER"
if [ -n "$OUTPUT_WIDTH" ] && [ -n "$OUTPUT_HEIGHT" ]; then
    wine explorer.exe /desktop=installer,"${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}" "$INSTALLER"
else
    wine "$INSTALLER"
fi

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
