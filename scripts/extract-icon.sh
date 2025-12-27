#!/bin/bash
# Extract icon from Windows executable
# Usage: ./scripts/extract-icon.sh <url> <output-file>

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <url> <output-file>"
    echo "Example: $0 https://archive.org/download/winmine_xp/WINMINE.EXE icon.png"
    exit 1
fi

URL="$1"
OUTPUT="$2"

# Convert to absolute path
if [[ "$OUTPUT" != /* ]]; then
    OUTPUT="$(pwd)/$OUTPUT"
fi

# Create parent directory if it doesn't exist
OUTPUT_DIR="$(dirname "$OUTPUT")"
mkdir -p "$OUTPUT_DIR"

# Check dependencies
if ! command -v wrestool &> /dev/null; then
    echo "Error: wrestool not found. Please install icoutils:"
    echo "  Fedora/RHEL: sudo dnf install icoutils"
    echo "  Debian/Ubuntu: sudo apt install icoutils"
    echo "  Arch: sudo pacman -S icoutils"
    exit 1
fi

if ! command -v icotool &> /dev/null; then
    echo "Error: icotool not found. Please install icoutils."
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "Downloading $URL..."
EXE_FILE="$TEMP_DIR/$(basename "$URL")"
curl -L -o "$EXE_FILE" "$URL"

echo "Extracting icon resources..."
cd "$TEMP_DIR"

# Extract icon resources (type 14 is icon group)
wrestool -x -t 14 "$EXE_FILE" > temp.ico 2>/dev/null || true

# If no icon group found, try extracting individual icons (type 3)
if [ ! -s temp.ico ]; then
    echo "No icon group found, trying individual icons..."
    wrestool -x -t 3 "$EXE_FILE" > temp.ico 2>/dev/null || true
fi

if [ ! -s temp.ico ]; then
    echo "Error: No icons found in executable"
    exit 1
fi

# Convert ico to png
icotool -x -o . temp.ico

# Find the best icon (prefer larger sizes)
BEST_ICON=""
for size in 256x256 128x128 96x96 64x64 48x48 32x32; do
    ICON=$(ls -1 *_${size}*.png 2>/dev/null | head -1 || true)
    if [ -n "$ICON" ]; then
        BEST_ICON="$ICON"
        break
    fi
done

# If no specific size found, use any png
if [ -z "$BEST_ICON" ]; then
    BEST_ICON=$(ls -1 *.png 2>/dev/null | head -1 || true)
fi

if [ -z "$BEST_ICON" ]; then
    echo "Error: No PNG icons extracted"
    exit 1
fi

echo "Found icon: $BEST_ICON"

# Copy to output location
cp "$BEST_ICON" "$OUTPUT"

echo "Icon extracted successfully to: $OUTPUT"
