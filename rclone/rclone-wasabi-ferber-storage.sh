#!/usr/bin/env bash
set -euo pipefail

# ========= Defaults =========
SRC_DEFAULT="~/Downloads"
# Default DEST_PREFIX includes today's date (YYYY-MM-DD)
DEST_PREFIX_DEFAULT="backups/$(date +%F)"

# Rclone remote & bucket
WASABI_REMOTE="wasabi-ferber"
DEST_BUCKET="ferber-storage"

# Flags
DRY_RUN=false
VERIFY=false
UPLOAD_CONCURRENCY=4          # rclone --s3-upload-concurrency
OPERATION="copy"              # default action; set to "sync" when --sync is passed

usage() {
  cat <<'EOF'
Usage:
  ./rclone-wasabi-ferber-storage.sh [SRC] [DEST_PREFIX] [--dry-run] [--verify] [--sync] [--upload-concurrency=N]

Positional:
  SRC            Source folder (default: /Volumes/Mando/Mods)
                 If it doesn't start with '/', '/' will be prepended.
  DEST_PREFIX    Destination key prefix in the bucket (default: backup-mando/YYYY-MM-DD)
  ALWAYS         wasabi-ferber:ferber-storage/<DEST_PREFIX>

Options:
  --dry-run                Show what would happen; no changes made
  --verify                 Run post-copy integrity check (rclone check)
  --sync                   Mirror mode (adds/updates and DELETES extras at dest)
                           Default without this flag is 'copy' (never deletes)
  --upload-concurrency=N   Parallel parts per large-object upload (default: 4)

Examples:
  ./rclone-wasabi-ferber-storage.sh
  ./rclone-wasabi-ferber-storage.sh "src" "dest" --dry-run --verify --sync --upload-concurrency=8
  ./rclone-wasabi-ferber-storage.sh "/Volumes/Mando" "backup-mando/2025-08-15" --verify
  ./rclone-wasabi-ferber-storage.sh "Volumes/Mando" "backup-mando/$(date +%F)" --dry-run
  ./rclone-wasabi-ferber-storage.sh "Volumes/Mando" --sync --upload-concurrency=8
EOF
}

# ========= Require arguments =========
if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

# ========= Parse args =========
POS_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --verify)  VERIFY=true ;;
    --sync)    OPERATION="sync" ;;
    --upload-concurrency=*) UPLOAD_CONCURRENCY="${arg#*=}" ;;
    -h|--help) usage; exit 0 ;;
    --*) echo "Unknown option: $arg" >&2; usage; exit 2 ;;
    *) POS_ARGS+=("$arg") ;;
  esac
done

SRC="${POS_ARGS[0]:-$SRC_DEFAULT}"
DEST_PREFIX="${POS_ARGS[1]:-$DEST_PREFIX_DEFAULT}"

# Normalize SRC and DEST_PREFIX
[[ "$SRC" != /* ]] && SRC="/$SRC"
DEST_PREFIX="${DEST_PREFIX#/}"   # strip leading slash if any

# ========= Prep =========
TS="$(date +"%Y%m%d-%H%M%S")"
LOG_DIR="$HOME/Logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup-$TS.txt"

DEST="${WASABI_REMOTE}:${DEST_BUCKET}/${DEST_PREFIX}"

echo "Log file (warnings/errors): $LOG_FILE"
echo "Source:      $SRC"
echo "Destination: $DEST"
echo "Mode:        $OPERATION  (copy = keep extras at dest, sync = delete extras)"
echo "Dry run:     $DRY_RUN"
echo "Verify:      $VERIFY"
echo "Upload concurrency: $UPLOAD_CONCURRENCY"
echo

# Sanity checks
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone not found. Install with: brew install rclone" | tee -a "$LOG_FILE" >&2; exit 1; }
[[ -d "$SRC" ]] || { echo "ERROR: Source not found: $SRC" | tee -a "$LOG_FILE" >&2; exit 1; }

# ========= Build rclone flags =========
RC_FLAGS=(
  -P --fast-list
  --s3-upload-concurrency "$UPLOAD_CONCURRENCY"
  --s3-chunk-size 128M
  --checkers 32
  --retries 8 --low-level-retries 20 --retries-sleep 10s
  --log-level WARNING --log-file "$LOG_FILE"
  --exclude ".DS_Store" --exclude "._*" --exclude ".Spotlight-*"
  --exclude ".Trashes"
)
$DRY_RUN && RC_FLAGS+=(--dry-run)

# ========= Copy/Sync =========
echo "Starting rclone $OPERATION..."
if [[ "$OPERATION" == "sync" ]]; then
  rclone sync "$SRC" "$DEST" "${RC_FLAGS[@]}"
else
  rclone copy "$SRC" "$DEST" "${RC_FLAGS[@]}"
fi

echo
echo "Transfer phase complete."

# ========= Verify (optional) =========
if $VERIFY; then
  echo
  echo "Starting verify (rclone check, one-way)..."
  # --one-way: ignore extra files in DEST (useful even after sync to focus on mismatches)
  rclone check "$SRC" "$DEST" --one-way --fast-list \
    --log-level WARNING --log-file "$LOG_FILE"
  RC=$?
  if [[ $RC -eq 0 ]]; then
    echo "VERIFY: No differences found."
  elif [[ $RC -eq 1 ]]; then
    echo "VERIFY: Differences detected! See details in: $LOG_FILE" >&2
    exit 3
  else
    echo "VERIFY: Fatal error during check. See: $LOG_FILE" >&2
    exit $RC
  fi
fi

echo
echo "All done."
echo "Warnings/errors (if any) were written to: $LOG_FILE"
