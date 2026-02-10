#!/usr/bin/env bash
# retag_from_staging.sh - Move Assets from Staging Album to Target Albums in Immich
#
# Reads album_diffs/*__missing.txt files to determine which assets in a staging
# album should be moved to their correct target albums. Matches by filename
# against assets already in the staging album, then adds them to the target
# album and removes from staging -- effectively "retagging" without re-upload.
#
# Usage:
#   export IMMICH_API_KEY="your-key"
#   DRY_RUN=true ./retag_from_staging.sh    # preview
#   DRY_RUN=false ./retag_from_staging.sh   # execute
#
# Environment variables:
#   IMMICH_API_KEY       (required) - Immich API key
#   STAGING_ALBUM_NAME   - Album to drain assets from (default: .immich_staging)
#   DRY_RUN              - "true" to preview, "false" to execute (default: "false")
#
# Prerequisites: curl, jq
set -euo pipefail

# --- config ---
IMMICH_URL="${IMMICH_URL:-https://photos.mykk.us/api}"
IMMICH_API_KEY="${IMMICH_API_KEY:?Set IMMICH_API_KEY}"
ALBUM_DIFF_DIR="${ALBUM_DIFF_DIR:-album_diffs}"
STAGING_ALBUM_NAME="${STAGING_ALBUM_NAME:-.immich_staging}"  # album to drain
DRY_RUN="${DRY_RUN:-false}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need curl; need jq

api_get(){ curl -fsSL -H "x-api-key: $IMMICH_API_KEY" -H "accept: application/json" "$IMMICH_URL$1"; }
api_post(){ curl -fsSL -H "x-api-key: $IMMICH_API_KEY" -H "content-type: application/json" -d "$2" "$IMMICH_URL$1"; }
api_del(){ curl -fsSL -X DELETE -H "x-api-key: $IMMICH_API_KEY" -H "content-type: application/json" -d "$2" "$IMMICH_URL$1"; }

album_id_by_name(){
  api_get "/albums" | jq -r --arg n "$1" '.[] | select(.albumName==$n) | .id' | head -n1
}

# Build a map: filename -> assetId for everything in the staging album
build_staging_index(){
  local aid="$1"
  api_get "/albums/$aid?withoutAssets=false" \
    | jq -r '.assets[] | [.originalFileName, .id] | @tsv'
}

add_assets_to_album(){
  local album_id="$1"; shift
  local ids_json
  ids_json=$(printf '"%s",' "$@" | sed 's/,$//')
  [[ "$DRY_RUN" == "true" ]] && { echo "[DRY] add -> $album_id : [$ids_json]"; return 0; }
  api_post "/albums/$album_id/assets" "{\"assetIds\":[${ids_json}]}" >/dev/null
}

remove_assets_from_album(){
  local album_id="$1"; shift
  local ids_json
  ids_json=$(printf '"%s",' "$@" | sed 's/,$//')
  [[ "$DRY_RUN" == "true" ]] && { echo "[DRY] remove <- $album_id : [$ids_json]"; return 0; }
  api_del "/albums/$album_id/assets" "{\"assetIds\":[${ids_json}]}" >/dev/null
}

main(){
  local staging_id target_id
  staging_id="$(album_id_by_name "$STAGING_ALBUM_NAME")"
  [[ -z "$staging_id" ]] && { echo "Could not find album: $STAGING_ALBUM_NAME"; exit 1; }

  echo "Indexing assets in '$STAGING_ALBUM_NAME'..."
  declare -A IDX # filename -> assetId (last one wins)
  while IFS=$'\t' read -r name id; do
    [[ -z "$name" || -z "$id" ]] && continue
    IDX["$name"]="$id"
  done < <(build_staging_index "$staging_id")

  shopt -s nullglob
  for missfile in "$ALBUM_DIFF_DIR"/*__missing.txt; do
    # Filename format: "<EnteAlbum>__VS__<ImmichAlbum>__missing.txt"
    base="$(basename "$missfile")"
    immich_album="${base%__missing.txt}"; immich_album="${immich_album#*__VS__}"

    target_id="$(album_id_by_name "$immich_album")"
    if [[ -z "$target_id" ]]; then
      echo "WARN: Immich album not found: $immich_album  (skip)"; continue
    fi

    # Collect asset IDs by reading filenames from the missing list
    ids=()
    while IFS= read -r fname || [[ -n "$fname" ]]; do
      [[ -z "$fname" ]] && continue
      aid="${IDX[$fname]:-}"
      if [[ -n "$aid" ]]; then
        ids+=("$aid")
      else
        echo "  Not in staging index (already moved or name differs?): $fname"
      fi
    done < "$missfile"

    [[ ${#ids[@]} -eq 0 ]] && continue

    echo "Adding ${#ids[@]} assets to '$immich_album' and removing from '$STAGING_ALBUM_NAME'..."
    # Add to target, then remove from staging
    add_assets_to_album "$target_id" "${ids[@]}"
    remove_assets_from_album "$staging_id" "${ids[@]}"
  done

  echo "Done."
}

main "$@"

