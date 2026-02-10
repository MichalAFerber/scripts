#!/usr/bin/env bash
# fill_missing_from_mando.sh - Upload Missing Photos from External Drive to Immich
#
# Searches a locally mounted drive (e.g., /Volumes/Mando) for files listed in
# album_diffs/*__missing.txt, stages them, then uploads to the correct Immich album.
# Uses Spotlight (mdfind) for fast lookup with find(1) fallback.
#
# Usage:
#   export IMMICH_API_KEY="your-key"
#   DRY_RUN=true ./fill_missing_from_mando.sh       # preview
#   DRY_RUN=false ./fill_missing_from_mando.sh      # execute
#
# Environment variables:
#   IMMICH_API_KEY  (required) - Immich API key
#   EXTERNAL_ROOT   - Mount point to search (default: /Volumes/Mando)
#   DRY_RUN         - "true" to preview, "false" to upload (default: "true")
#
# Prerequisites: curl, jq, immich CLI (optional, falls back to API)
set -euo pipefail

# ---------- CONFIG ----------
EXTERNAL_ROOT="${EXTERNAL_ROOT:-/Volumes/Mando}"     # your SanDisk G-Drive mount
ALBUM_DIFF_DIR="${ALBUM_DIFF_DIR:-album_diffs}"     # where *_missing.txt live
STAGING_DIR="${STAGING_DIR:-$HOME/.immich_staging}" # temp copy before upload

IMMICH_URL="${IMMICH_URL:-https://photos.mykk.us/api}"
IMMICH_API_KEY="${IMMICH_API_KEY:?Set IMMICH_API_KEY env var}"

DRY_RUN="${DRY_RUN:-true}"   # default to preview; set to "false" to actually do it

mkdir -p "$STAGING_DIR"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing tool: $1" >&2; exit 1; }; }
need awk; need sed; need grep; need tr; need curl; need jq
# immich CLI is optional (we fallback to API add-to-album if --album unsupported)
command -v immich >/dev/null 2>&1 || echo "NOTE: immich CLI not found; script will exit later."

# ---------- Immich helpers ----------
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
  # lightweight search for the most recent match by filename
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

# ---------- Finder (on local disk) ----------
spotlight_index_available() {
  # returns 0 if Spotlight can search this volume
  mdfind -onlyin "$EXTERNAL_ROOT" "kMDItemFSName == ''" >/dev/null 2>&1
}

find_on_volume() {
  # Find a file by name under EXTERNAL_ROOT, preferring:
  # 1) exact case via Spotlight (fast) then exact via find
  # 2) case-insensitive via Spotlight/find
  # 3) if many matches, prefer a path containing the album name (case-insensitive)
  local target="$1" album_name="$2"
  local out candidates line

  # Try Spotlight first if available
  if command -v mdfind >/dev/null 2>&1 && spotlight_index_available; then
    # Exact case
    mapfile -t candidates < <(mdfind -onlyin "$EXTERNAL_ROOT" "kMDItemFSName == '$target'cd" 2>/dev/null || true)
    # Fallback: case-insensitive (mdfind is naturally case-insensitive)
    if [[ ${#candidates[@]} -eq 0 ]]; then
      mapfile -t candidates < <(mdfind -onlyin "$EXTERNAL_ROOT" "kMDItemFSName == '$target'" 2>/dev/null || true)
    fi
    if [[ ${#candidates[@]} -gt 0 ]]; then
      # Prefer path containing album name
      local a_low; a_low="$(echo "$album_name" | tr '[:upper:]' '[:lower:]')"
      for line in "${candidates[@]}"; do
        if [[ "$(echo "$line" | tr '[:upper:]' '[:lower:]')" == *"$a_low"* ]]; then
          echo "$line"; return 0
        fi
      done
      echo "${candidates[0]}"; return 0
    fi
  fi

  # No Spotlight or no result — use find
  # 1) exact case
  out="$(/usr/bin/find "$EXTERNAL_ROOT" -type f -name "$target" -print -quit 2>/dev/null || true)"
  if [[ -n "$out" ]]; then echo "$out"; return 0; fi
  # 2) case-insensitive
  out="$(/usr/bin/find "$EXTERNAL_ROOT" -type f -iname "$target" -print 2>/dev/null || true)"
  if [[ -n "$out" ]]; then
    # prefer album-name in path if possible
    local a_low; a_low="$(echo "$album_name" | tr '[:upper:]' '[:lower:]')"
    while IFS= read -r line; do
      if [[ "$(echo "$line" | tr '[:upper:]' '[:lower:]')" == *"$a_low"* ]]; then
        echo "$line"; return 0
      fi
      candidates+=("$line")
    done <<< "$out"
    [[ ${#candidates[@]} -gt 0 ]] && echo "${candidates[0]}" && return 0
  fi

  return 1
}

immich_upload_to_album() {
  local album_name="$1" fpath="$2"
  if command -v immich >/dev/null 2>&1 && immich upload --help 2>/dev/null | grep -q -- "--album"; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY] immich upload --album \"$album_name\" \"$fpath\""
    else
      immich upload --album "$album_name" "$fpath"
    fi
  else
    # Fallback: upload, then add to album via API
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY] immich upload \"$fpath\""
      echo "[DRY] (then add to album \"$album_name\")"
    else
      immich upload "$fpath"
      local base; base="$(basename "$fpath")"
      local asset_id; asset_id="$(immich_asset_id_by_name_recent "$base")"
      if [[ -z "$asset_id" ]]; then
        echo "WARN: Could not resolve uploaded asset id for $base" >&2
        return 0
      fi
      local album_id; album_id="$(immich_album_id "$album_name")"
      if [[ -z "$album_id" ]]; then
        echo "WARN: Could not find album id for \"$album_name\"; asset uploaded but not added to album." >&2
        return 0
      fi
      immich_album_add_asset "$album_id" "$asset_id"
    fi
  fi
}

# ---------- Main ----------
shopt -s nullglob
count_missing_lists=0
for missfile in "$ALBUM_DIFF_DIR"/*__missing.txt; do
  count_missing_lists=$((count_missing_lists+1))
  base="$(basename "$missfile")"
  # filename format: "<EnteAlbum>__VS__<ImmichAlbum>__missing.txt"
  immich_album="${base%%__missing.txt}"
  immich_album="${immich_album##*__VS__}"

  echo "== Album: $immich_album =="
  while IFS= read -r fname || [[ -n "$fname" ]]; do
    [[ -z "$fname" ]] && continue
    echo "  → Looking for: $fname"
    if fpath="$(find_on_volume "$fname" "$immich_album")"; then
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
      echo "    NOT FOUND on $EXTERNAL_ROOT"
    fi
  done < "$missfile"
done

if [[ $count_missing_lists -eq 0 ]]; then
  echo "No *_missing.txt files found in $ALBUM_DIFF_DIR — nothing to do."
fi

echo "Done."

