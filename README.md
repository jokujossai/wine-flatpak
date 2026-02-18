# Wine Flatpak Games

Custom Flatpak packaging for Windows games using Wine, with gamescope integration for HiDPI scaling.

## Features

- **Modular Architecture**: Custom base runtime with Wine as a separate extension
- **Gamescope Integration**: Built-in upscaling for old games on modern displays
- **Simple Configuration**: Games configured via `config.ini`
- **32-bit Support**: Full multiarch support for old Windows games

## Installation

### Add Repository

```bash
flatpak remote-add --if-not-exists wine-flatpak https://jokujossai.github.io/wine-flatpak/wine-flatpak.flatpakrepo
```

### Install a Game

```bash
# Install minesweeper (includes required runtime and extensions)
flatpak install wine-flatpak io.github.jokujossai.wine.minesweeper

# Run
flatpak run io.github.jokujossai.wine.minesweeper
```

### Available Components

| Component | ID | Description |
|-----------|-----|-------------|
| Base Runtime | `io.github.jokujossai.wine.base` | Wine dependencies and utilities |
| Wine 10 | `io.github.jokujossai.wine.Version.wine-10` | Wine 10.x |
| Wine 10 WoW64 | `io.github.jokujossai.wine.Version.wine-10-wow64` | Wine 10.x (unified WoW64 build) |
| Wine 9 | `io.github.jokujossai.wine.Version.wine-9` | Wine 9.x (for compatibility) |
| Wine 9 WoW64 | `io.github.jokujossai.wine.Version.wine-9-wow64` | Wine 9.x (unified WoW64 build) |
| Gamescope | `io.github.jokujossai.gamescope` | Upscaling compositor |
| Gecko | `io.github.jokujossai.wine.support.gecko` | IE compatibility |
| Mono 8.1 | `io.github.jokujossai.wine.support.mono81` | .NET for Wine 8.x |
| Mono 9.3 | `io.github.jokujossai.wine.support.mono93` | .NET for Wine 9.x |
| Mono 10.3 | `io.github.jokujossai.wine.support.mono103` | .NET for Wine 10.x |
| Mono 10.4 | `io.github.jokujossai.wine.support.mono104` | .NET for Wine 11.x |
| Minesweeper | `io.github.jokujossai.wine.minesweeper` | Example game |

## Building from Source

### Build Components (in order)

```bash
# 1. Base runtime
cd base/io.github.jokujossai.wine.base
flatpak-builder --user --install --force-clean build io.github.jokujossai.wine.base.yml

# 2. Wine extension
cd ../../wine/io.github.jokujossai.wine.Version.wine-10
flatpak-builder --user --install --force-clean build io.github.jokujossai.wine.Version.wine-10.yml

# 3. (Optional) Gamescope extension
cd ../../extension/io.github.jokujossai.gamescope
flatpak-builder --user --install --force-clean build io.github.jokujossai.gamescope.yml
```

### Build and Run a Game

```bash
cd game/io.github.jokujossai.wine.minesweeper
flatpak-builder --user --install --force-clean build io.github.jokujossai.wine.minesweeper.yml
flatpak run io.github.jokujossai.wine.minesweeper
```

## Game Configuration

Games use `/app/config.ini`:

```ini
exe=/app/share/game/game.exe
installer=/app/share/game/setup.exe
windows_version=winxp
output_width=800
output_height=600
use_gamescope=1
```

## Environment Variables

- `USE_GAMESCOPE=0` - Disable gamescope
- `WINEDEBUG=+all` - Enable Wine debug output
- `WINE_VERSION=wine-10` - Select Wine version

## Troubleshooting

```bash
# Check components installed
flatpak list | grep io.github.jokujossai

# Debug mode
flatpak run --env=WINEDEBUG=+all io.github.jokujossai.wine.{game}

# Shell access
flatpak run --devel --command=bash io.github.jokujossai.wine.{game}

# Reset Wine prefix (preserves game saves if backup script exists)
flatpak run io.github.jokujossai.wine.{game} --reset
```

## License

MIT License for packaging scripts. See LICENSE for bundled component licenses.

Base manifest structure derived from [org.winehq.Wine](https://github.com/flathub/org.winehq.Wine).
