#!/usr/bin/env bash
# fill_missing_from_ente_export.sh - Upload Missing Photos from Ente Export to Immich
#
# Searches a local Ente Photos export directory for files listed in
# album_diffs/*__missing.txt (prefers album subfolder, falls back to whole export),
# then uploads them to the matching Immich album.
#
# Usage:
#   export IMMICH_API_KEY="your-key"
#   DRY_RUN=true ./fill_missing_from_ente_export.sh    # preview
#   DRY_RUN=false ./fill_missing_from_ente_export.sh   # execute
#
# Environment variables:
#   IMMICH_API_KEY  (required) - Immich API key
#   ENTE_ROOT       - Path to Ente export (default: ~/Downloads/Ente Photos)
#   DRY_RUN         - "true" to preview, "false" to upload (default: "true")
#
# Prerequisites: curl, jq, immich CLI
set -euo pipefail

# ----- CONFIG -----
ENTE_ROOT="${ENTE_ROOT:-/Users/michal/Downloads/Ente Photos}"  # your local Ente export root
ALBUM_DIFF_DIR="${ALBUM_DIFF_DIR:-album_diffs}"                # where *__missing.txt lives
STAGING_DIR="${STAGING_DIR:-$HOME/.immich_staging}"            # temp copy before upload

IMMICH_URL="${IMMICH_URL:-https://photos.mykk.us/api}"
IMMICH_API_KEY="${IMMICH_API_KEY:?Set IMMICH_API_KEY env var}"

DRY_RUN="${DRY_RUN:-true}"  # default to preview; set to "false" to actually upload

mkdir -p "$STAGING_DIR"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing tool: $1" >&2; exit 1; }; }
need awk; need sed; need grep; need tr; need curl; need jq
command -v immich >/dev/null 2>&1 || { echo "immich CLI not found in PATH"; exit 1; }

# ----- Immich helpers -----
api_get() {
  curl -fsSL -H "x-api-key: $IMMICH_API_KEY" -H "accept: application/json" "$IMMICH_URL$1"
}
api_post_json() {
  curl -fsSL -H "x-api-key: $IMMICH_API_KEY" -H "content-type: application/json" \
    -d "$2" "$IMMICH_URL$1"
}
immich_album_id() {
  local name="$1"
  api_get "/albums" | jq -r --arg n "$name" '.[] | select(.albumName==$n) | .id' | head -n1
}
immich_asset_id_by_name_recent() {
  local fname="$1"
  curl -fsSL -H "x-api-key: $IMMICH_API_KEY" -H "content-type: application/json" \
    -d '{"take":100,"skip":0,"withExif":false}' "$IMMICH_URL/search/metadata" \
    | jq -r --arg f "$fname" '
        ( .assets // .items // [] )
        | map(select(.originalFileName==$f))
        | sort_by(.createdAt // .fileCreatedAt // .id) | .[-1].id // empty'
}
immich_album_add_asset() {
  local album_id="$1" asset_id="$2"
  api_post_json "/albums/$album_id/assets" "{\"assetIds\":[\"$asset_id\"]}" >/dev/null
}
immich_upload_to_album() {
  local album_name="$1" fpath="$2"
  if immich upload --help 2>/dev/null | grep -q -- "--album"; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY] immich upload --album \"$album_name\" \"$fpath\""
    else
      immich upload --album "$album_name" "$fpath"
    fi
  else
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY] immich upload \"$fpath\" && add to \"$album_name\" via API"
    else
      immich upload "$fpath"
      local base; base="$(basename "$fpath")"
      local asset_id; asset_id="$(immich_asset_id_by_name_recent "$base")"
      [[ -z "$asset_id" ]] && { echo "WARN: Could not resolve uploaded asset id for $base"; return 0; }
      local album_id; album_id="$(immich_album_id "$album_name")"
      [[ -z "$album_id" ]] && { echo "WARN: Could not find album id for \"$album_name\""; return 0; }
      immich_album_add_asset "$album_id" "$asset_id"
    fi
  fi
}

# ----- File lookup inside Ente export -----
# Prefer exact album folder first; then whole export fallback.
find_in_album_then_export() {
  local fname="$1" ente_album="$2"
  local album_dir="$ENTE_ROOT/$ente_album"
  local out=""

  # 1) exact case inside album dir
  if [[ -d "$album_dir" ]]; then
    out="$(/usr/bin/find "$album_dir" -type f -name "$fname" -print -quit 2>/dev/null || true)"
    [[ -n "$out" ]] && { echo "$out"; return 0; }
    # 2) case-insensitive inside album dir
    out="$(/usr/bin/find "$album_dir" -type f -iname "$fname" -print -quit 2>/dev/null || true)"
    [[ -n "$out" ]] && { echo "$out"; return 0; }
  fi

  # 3) exact case across whole export
  out="$(/usr/bin/find "$ENTE_ROOT" -type f -name "$fname" -print -quit 2>/dev/null || true)"
  [[ -n "$out" ]] && { echo "$out"; return 0; }
  # 4) case-insensitive across whole export (first match)
  out="$(/usr/bin/find "$ENTE_ROOT" -type f -iname "$fname" -print 2>/dev/null | head -n1 || true)"
  [[ -n "$out" ]] && { echo "$out"; return 0; }

  return 1
}

# ----- Main -----
shopt -s nullglob
lists_found=0

for missfile in "$ALBUM_DIFF_DIR"/*__missing.txt; do
  lists_found=$((lists_found+1))
  base="$(basename "$missfile")"
  # Filename format: "<EnteAlbum>__VS__<ImmichAlbum>__missing.txt"
  ente_album="${base%%__VS__*}"
  immich_album="${base#*__VS__}"
  immich_album="${immich_album%__missing.txt}"

  echo "== Ente: $ente_album  →  Immich: $immich_album =="

  while IFS= read -r fname || [[ -n "$fname" ]]; do
    [[ -z "$fname" ]] && continue
    echo "  → Looking for: $fname"
    if fpath="$(find_in_album_then_export "$fname" "$ente_album")"; then
      echo "    Found: $fpath"
      dst="$STAGING_DIR/$fname"
      if [[ ! -f "$dst" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[DRY] cp -p \"$fpath\" \"$dst\""
        else
          cp -p "$fpath" "$dst"
        fi
      else
        echo "    Already staged: $dst"
      fi
      immich_upload_to_album "$immich_album" "$dst"
    else
      echo "    NOT FOUND under $ENTE_ROOT"
    fi
  done < "$missfile"
done

if [[ $lists_found -eq 0 ]]; then
  echo "No *_missing.txt files found in $ALBUM_DIFF_DIR — nothing to do."
fi

echo "Done."

