#!/usr/bin/env bash
# fill_missing_from_gdrive.sh - Upload Missing Photos from Google Drive to Immich
#
# Searches a Google Drive remote (via rclone) for files listed in
# album_diffs/*__missing.txt, downloads them to a local staging directory,
# then uploads to the correct Immich album via the immich CLI.
#
# Usage:
#   export IMMICH_API_KEY="your-key"
#   DRY_RUN=true ./fill_missing_from_gdrive.sh     # preview
#   DRY_RUN=false ./fill_missing_from_gdrive.sh    # execute
#
# Environment variables:
#   IMMICH_API_KEY  (required) - Immich API key
#   RCLONE_REMOTE   - rclone remote for GDrive (default: mando:)
#   DRY_RUN         - "true" to preview, "false" to upload (default: "false")
#
# Prerequisites: rclone, immich CLI, curl, jq
set -euo pipefail

# ----- CONFIG -----
RCLONE_REMOTE="${RCLONE_REMOTE:-mando:}"        # rclone remote name for your GDrive "Mando"
STAGING_DIR="${STAGING_DIR:-$HOME/.immich_staging}"
IMMICH_URL="${IMMICH_URL:-https://photos.mykk.us/api}"
IMMICH_API_KEY="${IMMICH_API_KEY:?set IMMICH_API_KEY}"
ALBUM_DIFF_DIR="${ALBUM_DIFF_DIR:-album_diffs}"
DRY_RUN="${DRY_RUN:-false}"                     # set to true to preview actions

mkdir -p "$STAGING_DIR"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_tools() {
  for t in rclone immich jq awk sed grep; do
    have_cmd "$t" || { echo "Missing required tool: $t" >&2; exit 1; }
  done
}

# Hit Immich API (GET)
api_get() {
  curl -fsSL -H "x-api-key: $IMMICH_API_KEY" -H "accept: application/json" "$IMMICH_URL$1"
}

# Hit Immich API (POST JSON)
api_post_json() {
  local path="$1"; shift
  curl -fsSL -H "x-api-key: $IMMICH_API_KEY" -H "content-type: application/json" \
    -d "$1" "$IMMICH_URL$path"
}

# Find album ID in Immich by album name
immich_album_id() {
  local name="$1"
  api_get "/albums" | jq -r --arg n "$name" '.[] | select(.albumName==$n) | .id' | head -n1
}

# After upload, find asset ID by filename (last uploaded wins)
immich_asset_id_by_name() {
  local fname="$1"
  # lightweight search using the search/metadata fallback (skip/take small)
  curl -fsSL -H "x-api-key: $IMMICH_API_KEY" -H "content-type: application/json" \
    -d '{"take":50,"skip":0,"withExif":false}' "$IMMICH_URL/search/metadata" \
    | jq -r --arg f "$fname" '.assets? // .items? // [] | map(select(.originalFileName==$f)) | .[-1].id // empty'
}

# Add asset to album
immich_album_add_asset() {
  local album_id="$1" asset_id="$2"
  api_post_json "/albums/$album_id/assets" "{\"assetIds\":[\"$asset_id\"]}" >/dev/null
}

# Upload via Immich CLI; prefer direct album assign if CLI supports it
immich_upload_to_album() {
  local album_name="$1" file="$2"
  if immich upload --help 2>/dev/null | grep -q -- "--album"; then
    [[ "$DRY_RUN" == "true" ]] && echo "[DRY] immich upload --album \"$album_name\" \"$file\"" && return 0
    immich upload --album "$album_name" "$file"
  else
    # Fallback: plain upload, then add to album via API
    [[ "$DRY_RUN" == "true" ]] && echo "[DRY] immich upload \"$file\"" && return 0
    immich upload "$file"
    local base="$(basename "$file")"
    local aid
    aid="$(immich_asset_id_by_name "$base")"
    if [[ -n "$aid" ]]; then
      local alb_id
      alb_id="$(immich_album_id "$album_name")"
      if [[ -n "$alb_id" ]]; then
        [[ "$DRY_RUN" == "true" ]] && echo "[DRY] Add $base ($aid) -> album $album_name ($alb_id)" && return 0
        immich_album_add_asset "$alb_id" "$aid"
      else
        echo "WARN: Cannot find album id for \"$album_name\"; uploaded but not added to album." >&2
      fi
    else
      echo "WARN: Cannot resolve asset id for \"$base\" after upload." >&2
    fi
  fi
}

# Find a file on GDrive (case-insensitive filename match). Returns first match path.
gdrive_find_first() {
  local needle="$1"
  # -R: recursive; print full relative path; case-insensitive grep
  rclone lsf -R "$RCLONE_REMOTE" 2>/dev/null | grep -i -F -- "$needle" | head -n1 || true
}

# Main
require_tools

shopt -s nullglob
for missfile in "$ALBUM_DIFF_DIR"/*__missing.txt; do
  # Extract "Ente__VS__Immich" parts from filename
  base="$(basename "$missfile")"
  # "...EnteName__VS__ImmichName__missing.txt"
  immich_album="$(printf "%s" "$base" | sed 's/.*__VS__\(.*\)__missing\.txt/\1/' | sed 's/_/ /g')"
  echo "== Album: $immich_album =="
  while IFS= read -r fn; do
    [[ -z "$fn" ]] && continue
    echo "  >> Searching GDrive for: $fn"
    relpath="$(gdrive_find_first "$fn")"
    if [[ -z "$relpath" ]]; then
      echo "     NOT FOUND on $RCLONE_REMOTE"
      continue
    fi
    echo "     Found: $relpath"
    src="$RCLONE_REMOTE$relpath"
    dst="$STAGING_DIR/$fn"
    if [[ ! -f "$dst" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY] rclone copyto \"$src\" \"$dst\""
      else
        rclone copyto "$src" "$dst"
      fi
    fi
    immich_upload_to_album "$immich_album" "$dst"
  done < "$missfile"
done

echo "Done."

