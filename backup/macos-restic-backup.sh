#!/usr/bin/env bash
# macOS → Restic (encrypted via rclone) nightly backup
set -euo pipefail

##### Variables (edit) #########################################################
RESTIC_REPO="${RESTIC_REPO:-rclone:wasabi-crypt:macos-restic}"
RESTIC_PASS_CMD="${RESTIC_PASSWORD_COMMAND:-security find-generic-password -w -s restic-pass || true}"
if [[ ${#BACKUP_PATHS[@]:-0} -eq 0 ]]; then BACKUP_PATHS=("/Users/$USER"); fi
EXCLUDES_FILE="${EXCLUDES_FILE:-$HOME/.config/restic/excludes.txt}"
LOG_DIR="${LOG_DIR:-$HOME/Logs}"
LOG_FILE="$LOG_DIR/restic-macos-$(date +%F).log"
RETENTION_ARGS="${RETENTION_ARGS:---keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 7}"
HC_URL="${HC_URL:-}"   # Healthchecks.io ping URL (optional)
DRY_RUN=false
###############################################################################

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"
      echo "  --dry-run   Show what restic would do without making changes"
      exit 0
      ;;
  esac
done

mkdir -p "$LOG_DIR" "$(dirname "$EXCLUDES_FILE")"
[ -f "$EXCLUDES_FILE" ] || cp "$(dirname "$0")/../examples/excludes-macos.txt" "$EXCLUDES_FILE" || true

export RESTIC_REPOSITORY="$RESTIC_REPO"
if [ -n "$RESTIC_PASS_CMD" ]; then
  export RESTIC_PASSWORD="$(bash -lc "$RESTIC_PASS_CMD")"
fi
if [ -z "${RESTIC_PASSWORD:-}" ]; then
  echo "[ERROR] RESTIC_PASSWORD not set or retrievable" | tee -a "$LOG_FILE"
  exit 1
fi

# Initialize repo if new
restic snapshots >/dev/null 2>&1 || restic init

# Build dry-run flag
RESTIC_DRY=()
if [[ "$DRY_RUN" == "true" ]]; then
  RESTIC_DRY=(--dry-run)
  echo "[DRY RUN] No changes will be made."
fi

# Backup
{
  echo "=== Restic macOS backup: $(date) ==="
  echo "Dry run: $DRY_RUN"
  restic backup --one-file-system --exclude-file "$EXCLUDES_FILE" "${BACKUP_PATHS[@]}" "${RESTIC_DRY[@]}"
  restic forget $RETENTION_ARGS --prune "${RESTIC_DRY[@]}"
  if [[ "$DRY_RUN" == "false" ]]; then
    restic check --read-data-subset=1%
  else
    echo "[DRY RUN] Skipping integrity check."
  fi
  echo "=== OK $(date) ==="
} | tee -a "$LOG_FILE"

# Healthchecks ping
[ -n "$HC_URL" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL" || true
