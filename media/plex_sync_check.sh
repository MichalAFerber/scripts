#!/usr/bin/env bash
# plex_sync_check.sh (v1.2)
# macOS-safe (Bash 3.2). Compares a source movie folder to a destination Plex folder by relative path.
#
# Modes:
#   --check  : report missing files
#   --copy   : copy missing files
#   --verify : checksum-verify files present in both places
#
set -euo pipefail

SRC_DIR="/Volumes/G-DRIVE 12TB/Movies"
DST_DIR="/Volumes/G-DRIVE 12TB/PlexMedia/Movies"
MODE="check"
REPORT_FILE=""
DRY_RUN="false"
QUIET="false"
EXTRA_EXCLUDES=()

timestamp() { date +"%Y-%m-%d %H:%M:%S"; }
log() { [[ "$QUIET" == "true" ]] || echo "[$(timestamp)] $*"; }
err() { echo "ERROR: $*" >&2; }

usage() {
  cat <<'EOF'
Usage:
  plex_sync_check.sh [--src <path>] [--dst <path>] [--check|--copy|--verify]
                     [--report <file>] [--exclude <glob>]... [--dry-run] [--quiet]
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --src) SRC_DIR="${2:-}"; shift 2;;
    --dst) DST_DIR="${2:-}"; shift 2;;
    --check) MODE="check"; shift;;
    --copy) MODE="copy"; shift;;
    --verify) MODE="verify"; shift;;
    --report) REPORT_FILE="${2:-}"; shift 2;;
    --exclude) EXTRA_EXCLUDES+=("${2:-}"); shift 2;;
    --dry-run) DRY_RUN="true"; shift;;
    --quiet) QUIET="true"; shift;;
    -h|--help) usage; exit 0;;
    *) err "Unknown option: $1"; usage; exit 1;;
  esac
done

[[ -d "$SRC_DIR" ]] || { err "Source not found: $SRC_DIR"; exit 2; }
[[ -d "$DST_DIR" ]] || { err "Destination not found: $DST_DIR"; exit 2; }

if [[ -z "$REPORT_FILE" ]]; then
  REPORT_FILE="./plex_sync_report-$(date +%Y%m%d-%H%M%S).csv"
fi

log "Source:      $SRC_DIR"
log "Destination: $DST_DIR"
log "Mode:        $MODE"
[[ "$DRY_RUN" == "true" ]] && log "Dry run:     YES"
log "Report:      $REPORT_FILE"

echo "status,relative_path,src_size_bytes,dst_size_bytes,src_sha256,dst_sha256" > "$REPORT_FILE"

# Defaults to ignore
DEFAULT_EXCLUDES=( ".DS_Store" "Thumbs.db" "@eaDir" )

sha256() {
  local f="$1"
  [[ -f "$f" ]] && shasum -a 256 "$f" | awk '{print $1}'
}

should_exclude() {
  local rel="$1"; local base="${rel##*/}"
  local name; for name in "${DEFAULT_EXCLUDES[@]}"; do [[ "$base" == "$name" ]] && return 0; done
  local pat; for pat in "${EXTRA_EXCLUDES[@]:-}"; do [[ "$rel" == $pat ]] && return 0; done
  return 1
}

present_count=0
missing_count=0
mismatch_count=0
copied_count=0

log "Scanning source tree... (this can take a while for big libraries)"

while IFS= read -r -d '' relpath; do
  rel="${relpath#./}"
  if should_exclude "$rel"; then continue; fi

  src="$SRC_DIR/$rel"
  dst="$DST_DIR/$rel"

  if [[ -f "$dst" ]]; then
    present_count=$((present_count+1))
    if [[ "$MODE" == "verify" ]]; then
      src_sz=$(stat -f%z "$src"); dst_sz=$(stat -f%z "$dst")
      src_hash=$(sha256 "$src");   dst_hash=$(sha256 "$dst")
      if [[ "$src_hash" != "$dst_hash" ]]; then
        echo "mismatch,\"$rel\",$src_sz,$dst_sz,$src_hash,$dst_hash" >> "$REPORT_FILE"
        mismatch_count=$((mismatch_count+1)); log "Checksum mismatch: $rel"
      else
        echo "ok,\"$rel\",$src_sz,$dst_sz,$src_hash,$dst_hash" >> "$REPORT_FILE"
      fi
    else
      src_sz=$(stat -f%z "$src"); dst_sz=$(stat -f%z "$dst")
      echo "ok,\"$rel\",$src_sz,$dst_sz,," >> "$REPORT_FILE"
    fi
  else
    missing_count=$((missing_count+1))
    src_sz=$(stat -f%z "$src")
    echo "missing,\"$rel\",$src_sz,0,," >> "$REPORT_FILE"

    if [[ "$MODE" == "copy" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY] Would copy: $rel"
      else
        mkdir -p "$(dirname "$dst")"
        if command -v rsync >/dev/null 2>&1; then
          RSYNC_FLAGS=(-aH)
          # Append flags only if supported (Homebrew rsync supports, Apple rsync may not)
          rsync --help 2>&1 | grep -q -- "--no-acls"   && RSYNC_FLAGS+=("--no-acls")
          rsync --help 2>&1 | grep -q -- "--no-xattrs" && RSYNC_FLAGS+=("--no-xattrs")
          rsync "${RSYNC_FLAGS[@]}" "$src" "$dst"
        else
          cp -p "$src" "$dst"
        fi
        copied_count=$((copied_count+1))
        log "Copied: $rel"
      fi
    else
      log "Missing: $rel"
    fi
  fi
done < <(cd "$SRC_DIR" && find . -type f -print0)

echo "========== SUMMARY =========="
echo "Source:           $SRC_DIR"
echo "Destination:      $DST_DIR"
echo "Mode:             $MODE"
echo "Files present:    $present_count"
echo "Files missing:    $missing_count"
if [[ "$MODE" == "verify" ]]; then
  echo "Checksum mismatches: $mismatch_count"
fi
if [[ "$MODE" == "copy" ]]; then
  echo "Files copied:     $copied_count"
  [[ "$DRY_RUN" == "true" ]] && echo "(Dry run: no files actually copied)"
fi
echo "Report CSV:       $REPORT_FILE"
echo "============================="
