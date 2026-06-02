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
DRY_RUN=false
###############################################################################

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"
      echo "  --dry-run   Show what rclone would do without making changes"
      exit 0
      ;;
  esac
done

RCLONE_DRY=()
if [[ "$DRY_RUN" == "true" ]]; then
  RCLONE_DRY=(--dry-run)
  echo "[DRY RUN] No changes will be made."
fi

mkdir -p "$(dirname "$LOG_FILE")"

{
  echo "=== rclone offsite sync: $(date) ==="
  echo "Dry run: $DRY_RUN"
  rclone sync "$LOCAL_SNAP_DIR" "$REMOTE" \
    --checksum --fast-list \
    --transfers="$TRANSFERS" --checkers="$CHECKERS" \
    --delete-after --stats 30s \
    "${RCLONE_DRY[@]}"
  echo "=== OK $(date) ==="
} | tee -a "$LOG_FILE"

[ -n "$HC_URL" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL" || true
