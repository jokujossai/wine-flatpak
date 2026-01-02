#!/bin/bash
# Restore minesweeper high scores and settings to Wine registry

BACKUP_FILE="/var/data/winmine-backup.reg"
USER_REG="$WINEPREFIX/user.reg"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "No backup file found, nothing to restore"
    exit 0
fi

if [ ! -f "$USER_REG" ]; then
    echo "No user.reg found, cannot restore"
    exit 0
fi

# Append the backed up section to user.reg
echo "" >> "$USER_REG"
cat "$BACKUP_FILE" >> "$USER_REG"

echo "Restored winmine settings from $BACKUP_FILE"
