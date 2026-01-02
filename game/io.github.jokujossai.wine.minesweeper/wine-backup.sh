#!/bin/bash
# Backup minesweeper high scores and settings from Wine registry

BACKUP_FILE="/var/data/winmine-backup.reg"
USER_REG="$WINEPREFIX/user.reg"

if [ ! -f "$USER_REG" ]; then
    echo "No user.reg found, nothing to backup"
    exit 0
fi

# Extract [Software\\Microsoft\\winmine] section
awk '
    /^\[Software\\\\Microsoft\\\\winmine\]/ { found=1; print; next }
    found && /^\[/ { found=0 }
    found { print }
' "$USER_REG" > "$BACKUP_FILE"

if [ -s "$BACKUP_FILE" ]; then
    echo "Backed up winmine settings to $BACKUP_FILE"
else
    rm -f "$BACKUP_FILE"
    echo "No winmine settings found to backup"
fi
