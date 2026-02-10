#!/usr/bin/env bash
# fill_scanning_elly.sh - Upload Missing "Scanning [Elly]" Album Files to Immich
#
# Single-album helper that finds missing files from the "Scanning [Elly]"
# album diff list in the Ente export and uploads them to Immich.
# Uses case-insensitive search with extension-twin and char-swap fallbacks.
#
# Usage:
#   export IMMICH_API_KEY="your-key"
#   ./fill_scanning_elly.sh
#
# Prerequisites: immich CLI, Ente export at ~/Downloads/Ente Photos
set -euo pipefail
ALBUM="Scanning [Elly]"
ROOT="/Users/michal/Downloads/Ente Photos"
MF="album_diffs/${ALBUM}__VS__${ALBUM}__missing.txt"

find_one() {
  local name="$1" p
  # prefer the album folder
  p="$(/usr/bin/find "$ROOT/$ALBUM" -type f -iname "$name" -print -quit 2>/dev/null || true)"; [[ -n "$p" ]] && { echo "$p"; return 0; }
  # then whole export
  p="$(/usr/bin/find "$ROOT" -type f -iname "$name" -print -quit 2>/dev/null || true)"; [[ -n "$p" ]] && { echo "$p"; return 0; }
  # extension twins
  local base="${name%.*}" ext="${name##*.}" cand alt
  for alt in jpg jpeg heic png; do
    [[ "$alt" == "$ext" ]] && continue
    cand="${base}.${alt}"
    p="$(/usr/bin/find "$ROOT/$ALBUM" -type f -iname "$cand" -print -quit 2>/dev/null || true)"; [[ -n "$p" ]] && { echo "$p"; return 0; }
    p="$(/usr/bin/find "$ROOT" -type f -iname "$cand" -print -quit 2>/dev/null || true)"; [[ -n "$p" ]] && { echo "$p"; return 0; }
  done
  # space/underscore/dash swaps
  local v
  for v in "$name" "${name// /_}" "${name// /-}" "${name//_ / }" "${name//_/ }" "${name//-/_}" "${name//-/ }"; do
    p="$(/usr/bin/find "$ROOT/$ALBUM" -type f -iname "$v" -print -quit 2>/dev/null || true)"; [[ -n "$p" ]] && { echo "$p"; return 0; }
    p="$(/usr/bin/find "$ROOT" -type f -iname "$v" -print -quit 2>/dev/null || true)"; [[ -n "$p" ]] && { echo "$p"; return 0; }
  done
  return 1
}

uploaded=0; missing=0
while IFS= read -r fname || [[ -n "$fname" ]]; do
  [[ -z "$fname" ]] && continue
  if fpath="$(find_one "$fname")"; then
    echo "+ $fname"
    immich upload --album "$ALBUM" "$fpath" >/dev/null
    uploaded=$((uploaded+1))
  else
    echo "! NOT FOUND in Ente export: $fname"
    missing=$((missing+1))
  fi
done < "$MF"

echo "== $ALBUM -> uploaded: $uploaded | not found: $missing =="
