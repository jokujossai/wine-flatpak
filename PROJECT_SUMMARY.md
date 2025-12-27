# Project Summary: Wine Flatpak Games

## Overview

Custom Flatpak packaging system for Windows games using Wine. Uses a modular architecture with a custom base runtime, Wine version extensions, and optional gamescope integration for HiDPI scaling.

## Current Status

**Working**:
- Base runtime with Wine dependencies
- Wine 10.x extension
- Gamescope extension
- Minesweeper game with config.ini-based configuration

## Architecture

### Modular Extension System

```
org.freedesktop.Platform (25.08)
    ↓ extends
io.github.jokujossai.wine.base (custom base runtime)
    ↓ uses as base              ↓ mounts extensions
Game Flatpak                    io.github.jokujossai.wine.Version.wine-10
                                io.github.jokujossai.gamescope
                                io.github.jokujossai.wine.gecko
                                io.github.jokujossai.wine.mono
```

### Components

1. **Base Runtime** (`io.github.jokujossai.wine.base`):
   - Wine dependencies: Kerberos, Samba, UnixODBC
   - Utilities: Zenity (dialogs), 7-Zip (archives)
   - Wine wrapper script for version selection
   - Universal entrypoint script
   - Extension mount points

2. **Wine Extension** (`io.github.jokujossai.wine.Version.wine-10`):
   - Wine 10.x binaries (64-bit and 32-bit)
   - Separate from base for easy version updates

3. **Gamescope Extension** (`io.github.jokujossai.gamescope`):
   - Custom-built gamescope compositor
   - Dependencies: XWayland, libinput, libei, libseat, LuaJIT

4. **Wine Gecko/Mono Extensions**:
   - Internet Explorer compatibility (Gecko)
   - .NET Framework implementation (Mono)

5. **Game Flatpaks**:
   - Use base runtime as base
   - Configure via `config.ini`
   - Mount Wine and optional extensions

## Key Files

### Base Runtime
- **Manifest**: `base/io.github.jokujossai.wine.base/io.github.jokujossai.wine.base.yml`
- **Wine Wrapper**: `base/io.github.jokujossai.wine.base/wine-wrapper`
- **Entrypoint**: `base/io.github.jokujossai.wine.base/entrypoint.sh`

### Game Example: Minesweeper
- **Manifest**: `game/io.github.jokujossai.wine.minesweeper/io.github.jokujossai.wine.minesweeper.yml`
- **Config**: `game/io.github.jokujossai.wine.minesweeper/config.ini`
- **Desktop**: `game/io.github.jokujossai.wine.minesweeper/io.github.jokujossai.wine.minesweeper.desktop`

## Universal Entrypoint

Games use a universal `entrypoint.sh` script configured via `config.ini`:

```ini
# Required
exe=/app/share/game/game.exe

# Optional
installer=/app/share/game/setup.exe
windows_version=winxp
output_width=800
output_height=600
use_gamescope=1
fullscreen=0
```

The entrypoint:
1. Initializes Wine prefix on first run
2. Sets Windows version if specified
3. Shows installer dialog if game not installed
4. Launches game with optional gamescope wrapper

## Decisions Made

### Why Custom Base Runtime?

**Previous approach**: Use `org.winehq.Wine` as base

**New approach**: Custom `io.github.jokujossai.wine.base`

**Reasons**:
- Control over Wine version selection via extensions
- Ability to add utilities (Zenity, 7-Zip) not in official Wine Flatpak
- Custom entrypoint system for game configuration
- More flexibility for future enhancements

### Why Wine as Extension?

**Benefits**:
- Easy Wine version updates without rebuilding base
- Support for multiple Wine versions simultaneously
- Faster game builds (Wine not rebuilt each time)
- Clear separation of concerns

### Why Custom Gamescope?

**Problem**: Flathub's gamescope extension has different paths and may not work with custom base

**Solution**: Build gamescope as extension for our base runtime

### Why config.ini?

**Previous approach**: Per-game launcher scripts

**New approach**: Universal entrypoint with `config.ini`

**Benefits**:
- Simpler game packaging (no custom scripts)
- Consistent behavior across games
- Easy to configure without code changes
- Environment variable overrides

## Build Order

Components must be built in this order:

1. Base runtime (`io.github.jokujossai.wine.base`)
2. Wine extension (`io.github.jokujossai.wine.Version.wine-10`)
3. Optional: Gamescope, Gecko, Mono extensions
4. Game Flatpaks

## Environment Variables

### Runtime Configuration
- `USE_GAMESCOPE` - Enable/disable gamescope (default: from config.ini or 1)
- `OUTPUT_WIDTH` / `OUTPUT_HEIGHT` - Override resolution
- `FULLSCREEN` - Force fullscreen mode
- `WINE_VERSION` - Select Wine version (default: wine-10)
- `WINEARCH` - Wine architecture (win32/win64/wow64)
- `WINEDEBUG` - Wine debug flags

## File Structure

```
wine/
├── base/
│   └── io.github.jokujossai.wine.base/
│       ├── io.github.jokujossai.wine.base.yml
│       ├── io.github.jokujossai.wine.base.metainfo.xml
│       ├── entrypoint.sh
│       ├── wine-wrapper
│       ├── wine-desktop
│       ├── extract-iso.sh
│       ├── ld.so.conf
│       └── krb5.conf
│
├── wine/
│   └── io.github.jokujossai.wine.Version.wine-10/
│       └── io.github.jokujossai.wine.Version.wine-10.yml
│
├── extension/
│   ├── io.github.jokujossai.gamescope/
│   │   ├── io.github.jokujossai.gamescope.yml
│   │   ├── io.github.jokujossai.gamescope.metainfo.xml
│   │   ├── fix-process-cleanup.patch
│   │   └── modules/
│   │       ├── libei.yml
│   │       ├── libevdev.yml
│   │       ├── libinput.yml
│   │       ├── libseat.yml
│   │       ├── luajit.yml
│   │       └── xwayland.yml
│   ├── io.github.jokujossai.wine.gecko/
│   └── io.github.jokujossai.wine.mono/
│
├── game/
│   └── io.github.jokujossai.wine.minesweeper/
│       ├── io.github.jokujossai.wine.minesweeper.yml
│       ├── io.github.jokujossai.wine.minesweeper.desktop
│       ├── io.github.jokujossai.wine.minesweeper.metainfo.xml
│       ├── config.ini
│       └── icon.png
│
├── scripts/
│   └── extract-icon.sh
│
├── README.md
├── PROJECT_SUMMARY.md
├── CONTRIBUTING.md
├── LICENSE
└── CLAUDE.md
```

## License

- **Packaging Scripts**: MIT License
- **Base Runtime Manifest**: Derived from org.winehq.Wine (MIT)
- **Wine**: LGPL-2.1-or-later
- **Gamescope**: BSD-2-Clause
- **Samba**: GPL-3.0-or-later
- **Games**: Retain original licenses (usually proprietary)

## Resources

- Wine: https://www.winehq.org/
- org.winehq.Wine: https://github.com/flathub/org.winehq.Wine
- Flatpak Docs: https://docs.flatpak.org/
- Gamescope: https://github.com/ValveSoftware/gamescope
