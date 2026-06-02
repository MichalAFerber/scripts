#!/usr/bin/env bash
# sync_movies.sh - One-Way Sync Movies to Plex Library with Confirmation
#
# Mirrors a source movie folder to a Plex media destination using rsync.
# Shows a dry-run preview first and asks for confirmation before applying.
# Uses --delete to remove files from destination that no longer exist in source.
#
# Usage:
#   ./sync_movies.sh              # interactive (shows preview, asks to confirm)
#   ./sync_movies.sh --dry-run    # dry-run only, no prompt
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

DRY_RUN_ONLY=false

# Parse args
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN_ONLY=true ;;
        -h|--help)
            echo "Usage: sync_movies.sh [--dry-run]"
            echo "  --dry-run  Show what would change without prompting or syncing"
            exit 0
            ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# 1) Dry-run: show what would change
echo "DRY RUN: changes to be made"
rsync -av --delete --dry-run \
    --exclude='.*' \
    "$SRC" "$DEST"

if $DRY_RUN_ONLY; then
    echo ""
    echo "Dry-run complete. No changes made."
    exit 0
fi

echo
read -p "Apply these changes? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rsync -av --delete \
        --exclude='.*' \
        "$SRC" "$DEST"
    echo "Sync complete."
else
    echo "Aborted; no changes made."
fi
