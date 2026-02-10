#!/bin/zsh
# upload_missing_from_ente.sh - Upload Missing Files from Ente Export to One Immich Album
#
# Takes a single album name, a missing-files list, and an Ente export root path,
# then searches for each file using case-insensitive matching with extension-twin
# and basename fallbacks, uploading found files to the specified Immich album.
#
# Usage:
#   export IMMICH_API_KEY="your-key"
#   ./upload_missing_from_ente.sh 'Album Name' 'album_diffs/...missing.txt' '/path/to/Ente'
#
# Arguments:
#   1. Immich album name
#   2. Path to missing-files list (one filename per line)
#   3. Root of Ente Photos export directory
#
# Prerequisites: immich CLI, zsh
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 '<Immich Album Name>' '<missing_list.txt>' '<ENTE_EXPORT_ROOT>'"
  echo "Example: $0 'Scanning [Elly]' 'album_diffs/Scanning [Elly]__VS__Scanning [Elly]__missing.txt' '/Users/michal/Downloads/Ente Photos'"
  exit 2
fi

album_name="$1"
missing_list="$2"
ENTE_ROOT="$3"

# sanity
[[ -f "$missing_list" ]] || { echo "Missing list not found: $missing_list"; exit 2; }
[[ -d "$ENTE_ROOT"    ]] || { echo "Ente export folder not found: $ENTE_ROOT"; exit 2; }

# case-insensitive find wrapper (fast exit on first hit)
find_one() {
  local root="$1" want="$2" p=""
  # exact (case-insensitive)
  p="$(/usr/bin/find "$root" -type f -iname "$want" -print -quit 2>/dev/null)"
  [[ -n "$p" ]] && { print -- "$p"; return 0; }
  return 1
}

# try common extension twins
twin_try() {
  local root="$1" base="$2" ext="$3" hit=""
  local twins=(jpg jpeg heic png JPG JPEG HEIC PNG)
  for alt in $twins; do
    [[ "${alt:l}" == "${ext:l}" ]] && continue
    hit="$(find_one "$root" "${base}.${alt}")" && { print -- "$hit"; return 0; }
  done
  return 1
}

# optional: basename-only fallback (e.g., name.*)
basename_try() {
  local root="$1" base="$2" hit=""
  hit="$(/usr/bin/find "$root" -type f -iname "${base}.*" -print -quit 2>/dev/null)"
  [[ -n "$hit" ]] && { print -- "$hit"; return 0; }
  return 1
}

added=0
missed=0
nf_file="$(basename "$missing_list" .txt)__still_missing_after_upload.txt"
: > "$nf_file"

echo "== Album: $album_name =="
while IFS= read -r fname || [[ -n "$fname" ]]; do
  [[ -z "$fname" ]] && continue

  # exact first
  if fpath="$(find_one "$ENTE_ROOT" "$fname")"; then
    echo "  + $fname  ->  $fpath"
    immich upload --album "$album_name" "$fpath" || true
    ((added++))
    continue
  fi

  # extension twins
  if [[ "$fname" == *.* ]]; then
    base="${fname%.*}"
    ext="${fname##*.}"
    if fpath="$(twin_try "$ENTE_ROOT" "$base" "$ext")"; then
      echo "  + $fname (twin)  ->  $fpath"
      immich upload --album "$album_name" "$fpath" || true
      ((added++))
      continue
    fi
    # basename-only fallback
    if fpath="$(basename_try "$ENTE_ROOT" "$base")"; then
      echo "  + $fname (basename)  ->  $fpath"
      immich upload --album "$album_name" "$fpath" || true
      ((added++))
      continue
    fi
  fi

  echo "  ! NOT FOUND in Ente export: $fname"
  print -- "$fname" >> "$nf_file"
  ((missed++))
done < "$missing_list"

echo ""
echo "Summary for '$album_name': uploaded $added | still missing $missed"
[[ -s "$nf_file" ]] && echo "Wrote list: $nf_file"

