# Claude Code Project Notes

This file contains context and notes for Claude Code when working on this project.

## Project Overview

Wine Flatpak Games - Custom packaging of Windows games using Wine and Flatpak, with gamescope integration for HiDPI displays. Uses a modular architecture with a custom base runtime, Wine as a separate extension, and a universal entrypoint system.

## Architecture

### Component Hierarchy

```
org.freedesktop.Platform (25.08)
    ↓ extends
io.github.jokujossai.wine.base
    ↓ uses as base              ↓ mounts extensions
Game Flatpak                    io.github.jokujossai.wine.Version.wine-10
                                io.github.jokujossai.gamescope
                                io.github.jokujossai.wine.gecko
                                io.github.jokujossai.wine.mono
```

### Components

1. **Base Runtime** (`io.github.jokujossai.wine.base`): Wine dependencies + utilities
2. **Wine Extension** (`io.github.jokujossai.wine.Version.wine-10`): Wine binaries
3. **Gamescope Extension** (`io.github.jokujossai.gamescope`): Upscaling compositor
4. **Gecko/Mono Extensions**: IE and .NET compatibility
5. **Game Flatpaks**: Individual games using base + extensions

## Key Files and Locations

### Base Runtime
- **Manifest**: `base/io.github.jokujossai.wine.base/io.github.jokujossai.wine.base.yml`
- **Metainfo**: `base/io.github.jokujossai.wine.base/io.github.jokujossai.wine.base.metainfo.xml`
- **Entrypoint**: `base/io.github.jokujossai.wine.base/entrypoint.sh`
- **Wine Wrapper**: `base/io.github.jokujossai.wine.base/wine-wrapper`
- **Wine Desktop**: `base/io.github.jokujossai.wine.base/wine-desktop`

### Wine Extension
- **Manifest**: `wine/io.github.jokujossai.wine.Version.wine-10/io.github.jokujossai.wine.Version.wine-10.yml`

### Gamescope Extension
- **Manifest**: `extension/io.github.jokujossai.gamescope/io.github.jokujossai.gamescope.yml`
- **Modules**: `extension/io.github.jokujossai.gamescope/modules/*.yml`
- **Patch**: `extension/io.github.jokujossai.gamescope/fix-process-cleanup.patch`

### Game Example: Minesweeper
- **Manifest**: `game/io.github.jokujossai.wine.minesweeper/io.github.jokujossai.wine.minesweeper.yml`
- **Config**: `game/io.github.jokujossai.wine.minesweeper/config.ini`
- **Desktop**: `game/io.github.jokujossai.wine.minesweeper/io.github.jokujossai.wine.minesweeper.desktop`
- **Metainfo**: `game/io.github.jokujossai.wine.minesweeper/io.github.jokujossai.wine.minesweeper.metainfo.xml`
- **Icon**: `game/io.github.jokujossai.wine.minesweeper/icon.png`

### Helper Scripts
- **Icon Extraction**: `scripts/extract-icon.sh`

## Important Conventions

### Naming
- **Base Runtime ID**: `io.github.jokujossai.wine.base`
- **Wine Extension Pattern**: `io.github.jokujossai.wine.Version.{version}`
- **Game App ID Pattern**: `io.github.jokujossai.wine.{gamename}`
- **All files must match app ID**

### File Structure for Games
```
game/io.github.jokujossai.wine.{gamename}/
├── io.github.jokujossai.wine.{gamename}.yml         # Flatpak manifest
├── io.github.jokujossai.wine.{gamename}.desktop     # Desktop entry
├── io.github.jokujossai.wine.{gamename}.metainfo.xml # AppStream metadata
├── config.ini                                        # Game configuration
└── icon.png                                          # App icon
```

## Universal Entrypoint System

Games are configured via `/app/config.ini` and use the universal `entrypoint.sh`:

```ini
# Required: Path to game executable
exe=/app/share/{gamename}/game.exe

# Optional: Installer for first-run
installer=/app/share/{gamename}/setup.exe

# Optional: Windows version (requires winetricks in prefix)
windows_version=winxp

# Optional: Gamescope output resolution
output_width=800
output_height=600

# Optional: Enable/disable features
use_gamescope=1
fullscreen=0
```

The entrypoint:
1. Reads `config.ini`
2. Initializes Wine prefix on first run
3. Sets Windows version if specified
4. Sets up D: drive if ISO contents exist
5. Shows installer dialog if game not installed
6. Launches game via `wine-desktop` wrapper

## Common Tasks

### Build Order (Required)
```bash
# 1. Build base runtime first
cd base/io.github.jokujossai.wine.base
flatpak-builder --user --install --force-clean build io.github.jokujossai.wine.base.yml

# 2. Build Wine extension
cd ../../wine/io.github.jokujossai.wine.Version.wine-10
flatpak-builder --user --install --force-clean build io.github.jokujossai.wine.Version.wine-10.yml

# 3. Optional: Build gamescope
cd ../../extension/io.github.jokujossai.gamescope
flatpak-builder --user --install --force-clean build io.github.jokujossai.gamescope.yml

# 4. Build game
cd ../../game/io.github.jokujossai.wine.{gamename}
flatpak-builder --user --install --force-clean build io.github.jokujossai.wine.{gamename}.yml
```

### Run Game
```bash
flatpak run io.github.jokujossai.wine.{gamename}
```

### Debug Game
```bash
# Shell access
flatpak run --devel --command=bash io.github.jokujossai.wine.{gamename}

# With Wine debug output
flatpak run --env=WINEDEBUG=+all io.github.jokujossai.wine.{gamename}

# Disable gamescope
USE_GAMESCOPE=0 flatpak run io.github.jokujossai.wine.{gamename}
```

### Extract Icon from .exe
```bash
scripts/extract-icon.sh <url-or-path-to-exe> <output-icon.png>
```

## Wine Extension Details

### Wine Wrapper Script
The `wine-wrapper` script at `/app/bin/wine` handles Wine version selection:
- Uses `WINE_VERSION` env var (default: `wine-10`)
- Looks for Wine in `/app/wine/${WINE_VERSION}/bin/`
- Handles win32/win64/wow64 architecture selection via `WINEARCH`

### Wine Desktop Wrapper
The `wine-desktop` script wraps games with optional gamescope:
- Reads `USE_GAMESCOPE` and resolution from config/env
- Launches gamescope if available and enabled
- Falls back to regular Wine if gamescope unavailable

## Extensions Configuration

### Base Runtime Extensions (inherited by games)
Games inherit these extensions from base via `inherit-extensions`:

```yaml
inherit-extensions:
  - org.freedesktop.Platform.Compat.i386
  - org.freedesktop.Platform.GL32
  - io.github.jokujossai.wine.gecko
  - io.github.jokujossai.wine.mono
  - io.github.jokujossai.gamescope
```

### Game-Specific Extensions
Games add their Wine version extension:

```yaml
add-extensions:
  io.github.jokujossai.wine.Version.wine-10:
    directory: wine/wine-10
    version: '25.08'
    add-ld-path: lib
```

## Game Manifest Template

```yaml
id: io.github.jokujossai.wine.{gamename}
runtime: org.freedesktop.Platform
runtime-version: '25.08'
sdk: org.freedesktop.Sdk
base: io.github.jokujossai.wine.base
base-version: '25.08'

command: entrypoint.sh

inherit-extensions:
  - org.freedesktop.Platform.Compat.i386
  - org.freedesktop.Platform.GL32
  - io.github.jokujossai.wine.gecko
  - io.github.jokujossai.wine.mono
  - io.github.jokujossai.gamescope

add-extensions:
  io.github.jokujossai.wine.Version.wine-10:
    directory: wine/wine-10
    version: '25.08'
    add-ld-path: lib

finish-args:
  - --share=ipc
  - --socket=x11
  - --socket=wayland
  - --socket=pulseaudio
  - --allow=multiarch
  - --device=dri
  - --env=WINEARCH=win32
  - --env=WINEPREFIX=/var/data/wine

modules:
  - name: {gamename}
    buildsystem: simple
    build-commands:
      - install -Dm644 game.exe /app/share/{gamename}/game.exe
      - install -Dm644 config.ini /app/config.ini
      - install -Dm644 *.desktop /app/share/applications/
      - install -Dm644 *.metainfo.xml /app/share/metainfo/
      - install -Dm644 icon.png /app/share/icons/hicolor/128x128/apps/{app-id}.png
      - mkdir -p /app/wine/wine-10
    sources:
      - type: file
        url: https://example.com/game.exe
        sha256: ...
        dest-filename: game.exe
      - type: file
        path: config.ini
      - type: file
        path: io.github.jokujossai.wine.{gamename}.desktop
      - type: file
        path: io.github.jokujossai.wine.{gamename}.metainfo.xml
      - type: file
        path: icon.png
```

## Environment Variables

### Game Runtime
- `USE_GAMESCOPE` - Enable/disable gamescope (default: from config.ini or 1)
- `OUTPUT_WIDTH` / `OUTPUT_HEIGHT` - Override gamescope resolution
- `FULLSCREEN` - Force fullscreen mode
- `WINE_VERSION` - Select Wine version (default: wine-10)
- `WINEARCH` - Wine architecture (win32/win64/wow64)
- `WINEPREFIX` - Wine prefix location
- `WINEDEBUG` - Wine debug flags

## Common Issues and Solutions

### Game doesn't start
1. Check base runtime installed: `flatpak list | grep io.github.jokujossai.wine.base`
2. Check Wine extension installed: `flatpak list | grep io.github.jokujossai.wine.Version`
3. Run with debug: `flatpak run --env=WINEDEBUG=+all ...`
4. Check config.ini exe path is correct

### Gamescope not working
1. Check extension installed: `flatpak list | grep io.github.jokujossai.gamescope`
2. Try without: `USE_GAMESCOPE=0 flatpak run ...`
3. Check binary exists in container: `/app/extensions/gamescope/bin/gamescope`

### Build fails
1. Ensure components built in order (base → wine → extensions → games)
2. Check runtime version matches: `25.08`
3. Verify extension mount points created in build-commands

## Wine Prefix Locations

Each game has isolated Wine prefix:
```
/var/data/wine (inside Flatpak container)
~/.var/app/io.github.jokujossai.wine.{gamename}/data/wine (on host)
```

## License Information

- **Packaging Scripts**: MIT License
- **Base Manifest Structure**: Derived from org.winehq.Wine (MIT)
- **Wine**: LGPL-2.1-or-later
- **Gamescope**: BSD-2-Clause
- **Samba**: GPL-3.0-or-later
- **Games**: Retain original licenses

## Git Ignored Items

Don't commit:
- `build/` - Flatpak build directory
- `.flatpak-builder/` - Flatpak builder cache
- `reference/` - Research materials
- `.claude/settings.local.json` - Claude Code local settings

## Tips for Claude Code

- Always check file exists before editing
- Verify app ID consistency across all files
- Build in correct order: base → wine → extensions → games
- Test builds after changes
- Keep manifest extension mount points in sync with add-extensions section
- Games use `entrypoint.sh` command (not custom launcher scripts)
- Use `config.ini` for game configuration
- WINEPREFIX should be `/var/data/wine` (Flatpak manages persistence)
- Desktop file Icon= field must match app ID
