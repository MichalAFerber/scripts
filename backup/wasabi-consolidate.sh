#!/usr/bin/env bash
# wasabi-consolidate.sh
# Move S3 "folders" (prefixes) in Wasabi with rclone, skip existing files at dest,
# then purge the source prefix. Dry-run by default; set DRY_RUN=false to execute.

set -euo pipefail

# --- CONFIG ---
REMOTE="wasabi-ferber:ferber-storage"
# Tuning flags (adjust if needed)
RCLONE_FLAGS=(-P --fast-list --ignore-existing --checkers=16 --transfers=16)

# Dry run safety: set to "false" to actually make changes
DRY_RUN="${DRY_RUN:-true}"

if [[ "${DRY_RUN}" == "true" ]]; then
  echo ">>> DRY RUN ENABLED (set DRY_RUN=false to apply changes)"
  RCLONE_FLAGS+=(--dry-run)
fi

move_merge() {
  local src="$1"   # e.g. backups-bookshelf
  local dst="$2"   # e.g. backups/2025-09-06

  # Ensure we operate on the *contents* of src by adding trailing slash when moving.
  echo ""
  echo "==> Moving contents: ${REMOTE}/${src%/}/  →  ${REMOTE}/${dst%/}/"
  echo "    (Skipping files that already exist at destination)"
  rclone move "${REMOTE}/${src%/}/" "${REMOTE}/${dst%/}/" "${RCLONE_FLAGS[@]}"

  # Purge the source prefix regardless of what remained (files skipped due to collisions, etc.)
  echo "==> Purging source prefix: ${REMOTE}/${src%/}/"
  # rclone purge also supports --dry-run; mirror our setting
  if [[ "${DRY_RUN}" == "true" ]]; then
    rclone purge "${REMOTE}/${src%/}/" --dry-run
  else
    rclone purge "${REMOTE}/${src%/}/"
  fi
}

echo "=== Preflight: showing current top-level prefixes in ${REMOTE}/ ==="
rclone lsf "${REMOTE}/" --dirs-only || true

# --- YOUR TASKS ---

# 1) Move contents of these folders to backups/ then delete the empty folder
move_merge "backup-mando"         "backups"
move_merge "backups-mando"        "backups"

# 2) Move contents of backups-bookshelf to backups/2025-09-06 then delete the empty folder
move_merge "backups-bookshelf"    "backups/2025-09-06"

# 3) Move contents of Backups-Bookshelf to backups/2025-09-04 then delete the empty folder
move_merge "Backups-Bookshelf"    "backups/2025-09-04"

# 4) Move contents of _DeleteMeAfterNov17 to backups/2025-08-17 then delete the empty folder
move_merge "_DeleteMeAfterNov17"  "backups/2025-08-17"

# 5) Move contents of _DeleteMeAfterNov18 to backups/2025-08-18 then delete the empty folder
move_merge "_DeleteMeAfterNov18"  "backups/2025-08-18"

echo ""
echo "=== Post-check: expected root prefixes are 'archives/', 'backups/', 'booklore/' ==="
rclone lsf "${REMOTE}/" --dirs-only || true

echo ""
echo "Done. If this looked good in DRY RUN, re-run with:"
echo "DRY_RUN=false bash ./wasabi-consolidate.sh"
