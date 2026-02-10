#!/usr/bin/env bash
# Sync snapshot folder to Wasabi (encrypted) with rclone
set -euo pipefail

##### Variables (edit) #########################################################
LOCAL_SNAP_DIR="${LOCAL_SNAP_DIR:-/backup/snapshots}"
REMOTE="${REMOTE:-wasabi-crypt:linux-snapshots}"
LOG_FILE="${LOG_FILE:-/var/log/rclone-offsite.log}"
TRANSFERS="${TRANSFERS:-8}"
CHECKERS="${CHECKERS:-16}"
HC_URL="${HC_URL:-}"   # Healthchecks.io ping URL (optional)
###############################################################################

mkdir -p "$(dirname "$LOG_FILE")"

{
  echo "=== rclone offsite sync: $(date) ==="
  rclone sync "$LOCAL_SNAP_DIR" "$REMOTE"     --checksum --fast-list     --transfers="$TRANSFERS" --checkers="$CHECKERS"     --delete-after --stats 30s
  echo "=== OK $(date) ==="
} | tee -a "$LOG_FILE"

[ -n "$HC_URL" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL" || true
