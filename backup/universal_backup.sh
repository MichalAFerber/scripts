#!/usr/bin/env bash
set -euo pipefail

# Universal Wasabi backup via rclone (Bash)
# - Auto-prompts if args missing
# - Logs start/end, command used, errors
# - Modes: copy (default) or sync
# - Optional excludes file (rsync-style patterns, one per line)
#
# Env overrides (via .env):
#   WUB_REMOTE (default: wasabi-ferber)
#   WUB_BUCKET (default: ferber-storage)
#   WUB_LOG_DIR (default: ~/Logs)
#   WUB_TRANSFERS (default: 8)
#   WUB_CHECKERS (default: 16)
#   WUB_BWLIMIT (default: none)
#
# Auto-date default for DEST_SUB (if omitted):
#   backup-$(hostname)/$(date +%F)

# Load .env if present
if [[ -f ".env" ]]; then
  # shellcheck disable=SC1091
  source ".env"
fi

REMOTE_NAME="${WUB_REMOTE:-wasabi-ferber}"
BUCKET="${WUB_BUCKET:-ferber-storage}"
REMOTE="${REMOTE_NAME}:${BUCKET}"

SRC=""
DEST_SUB=""
MODE="copy"        # copy|sync
DRY_RUN=false
VERIFY=false
TRANSFERS="${WUB_TRANSFERS:-8}"
CHECKERS="${WUB_CHECKERS:-16}"
BWLIMIT="${WUB_BWLIMIT:-}"
LOG_DIR_DEFAULT="${WUB_LOG_DIR:-$HOME/Logs}"
LOG_DIR="$LOG_DIR_DEFAULT"
EXCLUDES_FILE=""

print_help () {
  cat <<'EOF'
Universal Wasabi Backup (rclone) - Bash
--------------------------------------
Required:
  --src PATH             Source directory to back up

Optional:
  --dest-sub SUBPATH     Destination subfolder inside ferber-storage (default: backup-$(hostname)/YYYY-MM-DD)
  --mode copy|sync       copy (additive) or sync (mirror; deletes at dest). Default: copy
  --excludes PATH        File with exclude patterns (one per line)
  --dry-run              Show what would happen, no changes
  --verify               Run an rclone "check" pass after transfer
  --transfers N          Concurrent file transfers (default from env or 8)
  --checkers N           Concurrent checkers (default from env or 16)
  --bwlimit RATE         Limit bandwidth (e.g. 10M)
  --log-dir PATH         Where to write logs (default from env or ~/Logs)
  -h, --help             Show help

Examples:
  ./universal_backup.sh --src "/data/photos" --dest-sub "immich-raw" --mode sync --verify
  ./universal_backup.sh --src "/Volumes/Mando/archives" --excludes ./examples/excludes-common.txt --dry-run
EOF
}

# parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --src) SRC="${2:-}"; shift 2 ;;
    --dest-sub) DEST_SUB="${2:-}"; shift 2 ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --verify) VERIFY=true; shift ;;
    --transfers) TRANSFERS="${2:-$TRANSFERS}"; shift 2 ;;
    --checkers) CHECKERS="${2:-$CHECKERS}"; shift 2 ;;
    --bwlimit) BWLIMIT="${2:-}"; shift 2 ;;
    --log-dir) LOG_DIR="${2:-$LOG_DIR}"; shift 2 ;;
    --excludes) EXCLUDES_FILE="${2:-}"; shift 2 ;;
    -h|--help) print_help; exit 0 ;;
    *) echo "Unknown option: $1"; print_help; exit 2 ;;
  esac
done

# Prompt if missing
if [[ -z "$SRC" ]]; then
  read -r -p "Source folder path: " SRC
fi
if [[ -z "$DEST_SUB" ]]; then
  DEST_SUB="backup-$(hostname)/$(date +%F)"
  echo "Using default destination subfolder: $DEST_SUB"
fi
if [[ -z "$MODE" ]]; then
  read -r -p "Mode (copy|sync) [copy]: " MODE
  MODE="${MODE:-copy}"
fi

# validate
if [[ ! -d "$SRC" ]]; then
  echo "ERROR: Source not found or not a directory: $SRC" >&2
  exit 1
fi
if [[ "$MODE" != "copy" && "$MODE" != "sync" ]]; then
  echo "ERROR: --mode must be 'copy' or 'sync'." >&2
  exit 1
fi
if [[ -n "$EXCLUDES_FILE" && ! -f "$EXCLUDES_FILE" ]]; then
  echo "ERROR: --excludes file not found: $EXCLUDES_FILE" >&2
  exit 1
fi

# logging
mkdir -p "$LOG_DIR"
TS="$(date +"%Y%m%d-%H%M%S")"
LOG_FILE="$LOG_DIR/wasabi-backup-$TS.txt"

DEST="$REMOTE/$DEST_SUB"
CMD_MODE=(copy)
[[ "$MODE" == "sync" ]] && CMD_MODE=(sync)

# base flags
RCLONE_FLAGS=(
  --fast-list
  --checkers "$CHECKERS"
  --transfers "$TRANSFERS"
  --s3-storage-class STANDARD
  --create-empty-src-dirs
  --progress
  --human-readable
  --log-file "$LOG_FILE"
  --log-level INFO
)
[[ -n "$BWLIMIT" ]] && RCLONE_FLAGS+=(--bwlimit "$BWLIMIT")
$DRY_RUN && RCLONE_FLAGS+=(--dry-run)
[[ -n "$EXCLUDES_FILE" ]] && RCLONE_FLAGS+=(--exclude-from "$EXCLUDES_FILE")

echo "========== Universal Wasabi Backup =========="
echo "Start:       $(date)"
echo "Source:      $SRC"
echo "Destination: $DEST"
echo "Mode:        $MODE"
echo "Dry-run:     $DRY_RUN"
echo "Verify:      $VERIFY"
echo "Excludes:    ${EXCLUDES_FILE:-<none>}"
echo "Log file:    $LOG_FILE"
echo "============================================="
echo

# record the exact command used
{
  echo "----- COMMAND LINE -----"
  echo "rclone ${CMD_MODE[*]} \"$SRC\" \"$DEST\" ${RCLONE_FLAGS[*]}"
  echo "------------------------"
  echo
} >> "$LOG_FILE"

# run transfer
if ! rclone "${CMD_MODE[@]}" "$SRC" "$DEST" "${RCLONE_FLAGS[@]}"; then
  echo "ERROR: Transfer failed. See log: $LOG_FILE" >&2
  echo "End (failed): $(date)" >> "$LOG_FILE"
  exit 3
fi

# optional verify using rclone check
if $VERIFY; then
  echo
  echo "Starting verify pass (rclone check)..."
  {
    echo
    echo "----- VERIFY (rclone check) -----"
    echo "rclone check \"$SRC\" \"$DEST\" --one-way --size-only"
  } >> "$LOG_FILE"
  if ! rclone check "$SRC" "$DEST" --one-way --size-only --log-file "$LOG_FILE" --log-level INFO; then
    echo "VERIFY: Differences detected. See log: $LOG_FILE" >&2
    echo "End (verify differences): $(date)" >> "$LOG_FILE"
    exit 4
  fi
fi

echo
echo "All done."
echo "End: $(date)"
echo "Log: $LOG_FILE"
