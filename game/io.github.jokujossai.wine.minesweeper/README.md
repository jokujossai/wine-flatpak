# Minesweeper Flatpak Example

This is an example game Flatpak that demonstrates how to package old Windows games using the Wine extension system.

## Required Files

Before building this Flatpak, you need to provide the following files:

### 1. winmine.exe
The Windows Minesweeper executable is automatically downloaded from archive.org during the build process. No manual download required.

Source: https://archive.org/download/winmine_xp/WINMINE.EXE

### 2. icon.png
A 128x128 PNG icon for the application. You can:
- Extract the icon from winmine.exe using a resource editor
- Create your own icon
- Use a mine/flag themed icon

## Building

### Prerequisites
```bash
# Install required Flatpak runtimes and SDKs
flatpak install flathub org.freedesktop.Platform//25.08
flatpak install flathub org.freedesktop.Sdk//25.08
flatpak install flathub org.freedesktop.Sdk.Compat.i386//25.08
flatpak install flathub org.freedesktop.Sdk.Extension.toolchain-i386//25.08
```

### Build Wine Extension First
```bash
cd ../../extension/io.github.jokujossai.wine-10
flatpak-builder --user --install --force-clean build io.github.jokujossai.wine-10.yml
```

### Build Minesweeper
```bash
cd ../../game/io.github.jokujossai.wine.minesweeper
flatpak-builder --user --install --force-clean build io.github.jokujossai.wine.minesweeper.yml
```

## Running

### Normal mode
```bash
flatpak run io.github.jokujossai.wine.minesweeper
```

### Without gamescope
```bash
USE_GAMESCOPE=0 flatpak run io.github.jokujossai.wine.minesweeper
```

### Custom gamescope resolution
```bash
GAMESCOPE_GAME_WIDTH=800 GAMESCOPE_GAME_HEIGHT=600 flatpak run io.github.jokujossai.wine.minesweeper
```

## Environment Variables

- `USE_GAMESCOPE` - Set to 0 to disable gamescope (default: 1)
- `GAMESCOPE_GAME_WIDTH` - Game internal width (default: 640)
- `GAMESCOPE_GAME_HEIGHT` - Game internal height (default: 480)
- `GAMESCOPE_DISPLAY_WIDTH` - Display width (default: auto-detect)
- `GAMESCOPE_DISPLAY_HEIGHT` - Display height (default: auto-detect)
- `GAMESCOPE_EXTRA_OPTS` - Additional gamescope options
- `WINEPREFIX` - Wine prefix location (default: ~/.var/app/io.github.jokujossai.wine.minesweeper/wine)
- `WINEARCH` - Wine architecture (default: win64)

## Development

### Testing in development mode
```bash
flatpak run --devel --command=bash io.github.jokujossai.wine.minesweeper

# Inside container:
wine --version                # Check Wine version
ls /app/wine                 # Verify Wine extension is mounted
/app/bin/minesweeper-launcher  # Test launcher directly
```

### Debugging Wine
```bash
WINEDEBUG=+all flatpak run io.github.jokujossai.wine.minesweeper
```

## Adapting for Other Games

This example can be adapted for other old Windows games:

1. Replace `winmine.exe` with your game executable
2. Update the icon
3. Modify the manifest:
   - Change `id` to match your game
   - Update `name`, `summary`, and `description`
   - Adjust Wine version if needed (wine-8, wine-9, or wine-10)
   - Add any additional game files or dependencies
4. Update the launcher script if the game needs special setup
5. Adjust gamescope resolution defaults for your game

## License

This packaging is under MIT license. The Minesweeper game itself is proprietary software owned by Microsoft.
