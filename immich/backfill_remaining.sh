#!/usr/bin/env bash
# backfill_remaining.sh - Bulk Upload Remaining Missing Files from Ente to Immich
#
# Iterates over all album_diffs/*__missing.txt files and uploads matching files
# from the local Ente export directly into their target Immich albums using the
# immich CLI's --album flag. Uses case-insensitive search within the album's
# export subfolder first, then falls back to searching the entire export.
#
# Usage:
#   export IMMICH_API_KEY="your-key"
#   ./backfill_remaining.sh                # execute uploads
#   DRY_RUN=1 ./backfill_remaining.sh      # preview only
#
# Prerequisites: immich CLI
set -euo pipefail

ENTE_ROOT="/Users/michal/Downloads/Ente Photos"
DIFF_DIR="album_diffs"
DRY_RUN="${DRY_RUN:-}"   # set DRY_RUN=1 to test

shopt -s nullglob
for miss in "$DIFF_DIR"/*__missing.txt; do
  # Parse "Album__VS__Album__missing.txt"
  base="$(basename "$miss")"
  ente_album="${base%%__VS__*}"
  rest="${base#*__VS__}"
  immich_album="${rest%%__missing.txt}"

  echo -e "\n== $ente_album  →  $immich_album =="

  # Collect existing paths for this album
  mapfile -t paths < <(sed -e '/^[[:space:]]*$/d' "$miss" \
    | while IFS= read -r rel; do
        # try exact name first
        p="$ENTE_ROOT/$ente_album/$rel"
        if [[ -f "$p" ]]; then
          printf '%s\n' "$p"
          continue
        fi
        # fallback: case-insensitive search of the album for basename
        name="$(basename "$rel")"
        find "$ENTE_ROOT/$ente_album" -type f -iname "$name" -print
      done | sort -u)

  if (( ${#paths[@]} == 0 )); then
    echo "  (no files found for this album’s missing list)"
    continue
  fi

  if [[ -n "${DRY_RUN}" ]]; then
    for p in "${paths[@]}"; do echo "  + would upload: $p"; done
  else
    # Upload in one go; immich CLI will dedupe and (re)attach to album
    printf '%s\0' "${paths[@]}" \
      | xargs -0 immich upload --album "$immich_album"
  fi
done

