#!/bin/bash
# ISO extraction helper for Wine Flatpak games
# Usage: extract-iso.sh <iso-file>

set -e

if [ $# -ne 1 ]; then
    echo "Usage: extract-iso.sh <iso-file>" >&2
    exit 1
fi

ISO_FILE="$1"

if [ ! -f "$ISO_FILE" ]; then
    echo "Error: ISO file not found: $ISO_FILE" >&2
    exit 1
fi

# Extract ISO contents using 7z
echo "Extracting ISO: $ISO_FILE"
mkdir -p "iso_contents"
/app/bin/7z x "$ISO_FILE" -o"iso_contents" -y

# Verify extraction succeeded
if [ ! -d "iso_contents" ] || [ -z "$(ls -A iso_contents)" ]; then
    echo "Error: ISO extraction failed or resulted in empty directory" >&2
    exit 1
fi

echo "ISO extracted successfully to iso_contents/"
