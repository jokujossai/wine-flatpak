# Contributing Guide

Thank you for your interest in contributing to the Wine Flatpak Extensions project!

## Ways to Contribute

1. **Add new games** - Package additional old Windows games
2. **Improve Wine extensions** - Optimize builds, add features
3. **Documentation** - Improve guides, fix typos, add examples
4. **Bug fixes** - Fix issues with existing packages
5. **Testing** - Test games on different systems and report compatibility

## Getting Started

1. Fork the repository
2. Set up your development environment (see [BUILD.md](BUILD.md))
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Adding a New Game

### Steps

1. **Create game directory**:
   ```bash
   cp -r reference/examples/game-template game/io.github.jokujossai.wine.{gamename}
   cd game/io.github.jokujossai.wine.{gamename}
   ```

2. **Gather game files**:
   - Game executable(s)
   - Game data files
   - Icon (128x128 PNG)
   - README with source information

3. **Update manifest**:
   - Change `id` to `io.github.jokujossai.wine.{gamename}`
   - Update name, summary, description
   - Choose appropriate Wine version (8, 9, or 10)
   - Add game files to sources
   - Configure finish-args for game requirements

4. **Update metainfo**:
   - Fill in game description
   - Add screenshots (if available)
   - Set content rating
   - Add keywords

5. **Create launcher**:
   - Update `scripts/{gamename}-launcher`
   - Configure Wine settings
   - Add gamescope if needed
   - Test game launch

6. **Test**:
   ```bash
   flatpak-builder --user --install --force-clean build io.github.jokujossai.wine.{gamename}.yml
   flatpak run io.github.jokujossai.wine.{gamename}
   ```

7. **Document compatibility**:
   - Create README.md for the game
   - Note any special requirements
   - List tested systems
   - Document known issues

### Naming Conventions

- **ID**: `io.github.jokujossai.wine.{gamename}` (lowercase, no spaces)
- **Display Name**: "Original Game Name"
- **Files**: Match the ID exactly

### Required Files

Each game must have:
- `io.github.jokujossai.wine.{gamename}.yml` - Manifest
- `io.github.jokujossai.wine.{gamename}.metainfo.xml` - AppStream data
- `io.github.jokujossai.wine.{gamename}.desktop` - Desktop entry
- `scripts/{gamename}-launcher` - Launch script
- `icon.png` - Application icon (128x128)
- `README.md` - Game-specific documentation

### Wine Version Selection

| Wine Version | Use When |
|--------------|----------|
| wine-8 | Very old games (pre-2000), known issues with newer Wine |
| wine-9 | Balanced choice for most games (2000-2010) |
| wine-10 | Newer games, when latest features are needed |

## Adding a New Wine Version

When a new Wine version is released:

1. **Copy existing extension**:
   ```bash
   cp -r extension/io.github.jokujossai.wine-10 extension/io.github.jokujossai.wine-11
   ```

2. **Update manifest**:
   - Change `id` to `io.github.jokujossai.wine-11`
   - Update Wine source URL and version
   - Update Wine source SHA256
   - Check if configure options changed
   - Update FAudio version if needed
   - Update VKD3D version if needed

3. **Update metainfo**:
   - Update version number and release date
   - Add release notes
   - Update description if Wine added relevant features

4. **Build and test**:
   ```bash
   flatpak-builder --user --install --force-clean build io.github.jokujossai.wine-11.yml
   flatpak run --command=wine io.github.jokujossai.wine-11 --version
   ```

5. **Test with games**:
   - Test at least one game with new Wine version
   - Document any compatibility changes

## Code Style

### Manifest Files (YAML)

- Use 2-space indentation
- Keep lines under 100 characters where possible
- Group related options together
- Add comments for non-obvious configurations

```yaml
# Good
config-opts:
  - --enable-win64        # 64-bit Wine
  - --with-mingw          # MinGW PE builds
  - --disable-tests       # Skip tests

# Avoid
config-opts:
  - --enable-win64
  - --with-mingw
  - --disable-tests
```

### Shell Scripts

- Use `#!/bin/bash` shebang
- Use `set -e` to fail on errors
- Quote variables: `"$VARIABLE"`
- Add comments for complex logic
- Make scripts executable: `chmod +x script.sh`

```bash
#!/bin/bash
# Script description

set -e

# Configuration
GAME_DIR="/app/share/minesweeper"
WINE_PATH="/app/wine/bin/wine"

# Execute with error checking
if [ ! -f "$GAME_DIR/game.exe" ]; then
    echo "Error: Game executable not found"
    exit 1
fi

exec "$WINE_PATH" "$GAME_DIR/game.exe" "$@"
```

### Metainfo Files (XML)

- Use 2-space indentation
- Include all required fields
- Validate with: `appstream-util validate-relax file.metainfo.xml`
- Use proper content ratings

## Testing Requirements

Before submitting a pull request:

1. **Build test**:
   ```bash
   flatpak-builder --force-clean build manifest.yml
   ```

2. **Install test**:
   ```bash
   flatpak-builder --user --install --force-clean build manifest.yml
   ```

3. **Run test**:
   ```bash
   flatpak run io.github.jokujossai.wine.{app}
   ```

4. **Validation test**:
   ```bash
   appstream-util validate-relax *.metainfo.xml
   desktop-file-validate *.desktop
   ```

5. **Gamescope test** (if applicable):
   ```bash
   flatpak run io.github.jokujossai.wine.{app}
   USE_GAMESCOPE=0 flatpak run io.github.jokujossai.wine.{app}
   ```

## Documentation

### Required Documentation

- **README.md** for each game explaining:
  - Where to get game files
  - Build instructions
  - Known issues
  - Testing status

- **Code comments** for:
  - Complex configurations
  - Workarounds for bugs
  - Non-obvious choices

### Documentation Style

- Use clear, concise language
- Include code examples
- Add links to external resources
- Keep formatting consistent
- Use proper markdown

## Pull Request Process

1. **Fork and branch**:
   ```bash
   git checkout -b add-game-{gamename}
   ```

2. **Make changes**:
   - Follow code style guidelines
   - Test thoroughly
   - Update documentation

3. **Commit**:
   ```bash
   git add .
   git commit -m "Add {gamename} Flatpak"
   ```

4. **Push**:
   ```bash
   git push origin add-game-{gamename}
   ```

5. **Create pull request**:
   - Clear title describing the change
   - Detailed description
   - List testing performed
   - Screenshots if relevant

### Commit Message Format

```
Type: Brief description

Detailed explanation of changes if needed.

- List of changes
- Another change

Tested on: [System info]
```

Types:
- `Add:` New game or feature
- `Fix:` Bug fix
- `Update:` Update to existing package
- `Docs:` Documentation changes
- `Refactor:` Code restructuring

Example:
```
Add: Minesweeper Flatpak

Add Windows XP Minesweeper as example game Flatpak.

- Uses Wine 10 extension
- Includes gamescope support
- Downloads game from archive.org
- Full desktop integration

Tested on: Fedora 43
```

## Licensing

- All contributions must be compatible with MIT license
- Document sources for game files
- Respect original game licenses
- Include attribution where required

## Getting Help

- Create an issue for questions
- Check existing issues first
- Provide system information
- Include build logs for build issues
- Describe steps to reproduce problems

## Recognition

Contributors will be acknowledged in:
- Project README
- Release notes
- Individual game/extension documentation

Thank you for contributing!
