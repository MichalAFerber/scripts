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
###############################################################################

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

# Backup
{
  echo "=== Restic macOS backup: $(date) ==="
  restic backup --one-file-system --exclude-file "$EXCLUDES_FILE" "${BACKUP_PATHS[@]}"
  restic forget $RETENTION_ARGS --prune
  restic check --read-data-subset=1%
  echo "=== OK $(date) ==="
} | tee -a "$LOG_FILE"

# Healthchecks ping
[ -n "$HC_URL" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL" || true
