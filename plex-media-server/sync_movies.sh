#!/usr/bin/env bash
# sync_movies.sh - One-Way Sync Movies to Plex Library with Confirmation
#
# Mirrors a source movie folder to a Plex media destination using rsync.
# Shows a dry-run preview first and asks for confirmation before applying.
# Uses --delete to remove files from destination that no longer exist in source.
#
# Usage:
#   ./sync_movies.sh
#
# Paths (hardcoded):
#   Source:      /Volumes/G-DRIVE 12TB/Movies/
#   Destination: /Volumes/G-DRIVE 12TB/PlexMedia/Movies/
#
# The --exclude='.*' flag skips hidden files (e.g., .DS_Store).
set -euo pipefail

# Paths
SRC="/Volumes/G-DRIVE 12TB/Movies/"
DEST="/Volumes/G-DRIVE 12TB/PlexMedia/Movies/"

# 1) Dry‑run: show what would change
echo "DRY RUN: changes to be made"
rsync -av --delete --dry-run \
    --exclude='.*' \
    "$SRC" "$DEST"

echo
read -p "Apply these changes? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rsync -av --delete \
        --exclude='.*' \
        "$SRC" "$DEST"
    echo "✅ Sync complete."
else
    echo "Aborted; no changes made."
fi
