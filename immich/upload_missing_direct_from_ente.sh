#!/usr/bin/env bash
# upload_missing_direct_from_ente.sh - Batch Upload Missing Files from Ente to Immich
#
# Reads album_diffs/*__missing.txt files and directly uploads matches from the
# Ente Photos export to the corresponding Immich albums. Uses heuristic filename
# matching (extension twins, suffix stripping, char-swap variants) to find files
# that may have slightly different names.
#
# Usage:
#   export IMMICH_API_KEY="your-key"
#   ./upload_missing_direct_from_ente.sh
#
# Environment variables:
#   ENTE_ROOT       - Path to Ente export (default: ~/Downloads/Ente Photos)
#   ALBUM_DIFF_DIR  - Dir with *__missing.txt files (default: album_diffs)
#
# Prerequisites: immich CLI
set -euo pipefail

# CONFIG
ENTE_ROOT="${ENTE_ROOT:-/Users/michal/Downloads/Ente Photos}"
ALBUM_DIFF_DIR="${ALBUM_DIFF_DIR:-album_diffs}"
# Leave empty () to process all albums with missing lists.
REMAIN_FILTER=(
  "Scanning [Elly]"
  "Zach - The Early Years"
  "Em Green Book"
  "MAF White Book"
  "Scanning [Eli]"
  "MAF Green Book"
  "Michal"
  "House - Florence, Harborough Ct"
  "Emily"
  "Family & friends"
)

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
need immich

# Normalize helpers
swap_chars_variants() {
  # Generate simple name variants swapping space/_/-
  local s="$1"
  printf "%s\n" \
    "$s" \
    "${s// /_}" "${s// /-}" \
    "${s//_/ }" "${s//_/ -}" "${s//_/-}" \
    "${s//-/_}" "${s//-/ }"
}

strip_suffix_variants() {
  # Remove common camera/export suffixes
  local b="$1" out=()
  out+=("$b")
  out+=("${b%_mp}")
  out+=("${b%_edited}")
  out+=("${b%_edit}")
  out+=("${b% (1)}" "${b% (2)}" "${b% (3)}")
  out+=("${b%-1}" "${b%-2}" "${b%-3}")
  # de-dup
  printf "%s\n" "${out[@]}" | awk '!seen[$0]++'
}

try_ext_variants() {
  # Try a few likely extension twins
  local base="$1" ext="$2"
  printf "%s\n" "${base}.${ext}"
  for alt in jpg jpeg JPG JPEG heic HEIC png PNG; do
    [[ "$alt" == "$ext" ]] && continue
    printf "%s\n" "${base}.${alt}"
  done
}

find_one() {
  # search album dir (exact then -iname), then whole export; returns first hit
  local fname="$1" album="$2" root="$3" p
  if [[ -d "$root/$album" ]]; then
    p="$(/usr/bin/find "$root/$album" -type f -name "$fname" -print -quit 2>/dev/null || true)"; [[ -n "$p" ]] && { echo "$p"; return 0; }
    p="$(/usr/bin/find "$root/$album" -type f -iname "$fname" -print -quit 2>/dev/null || true)"; [[ -n "$p" ]] && { echo "$p"; return 0; }
  fi
  p="$(/usr/bin/find "$root" -type f -name "$fname" -print -quit 2>/dev/null || true)";     [[ -n "$p" ]] && { echo "$p"; return 0; }
  p="$(/usr/bin/find "$root" -type f -iname "$fname" -print 2>/dev/null | head -n1 || true)";[[ -n "$p" ]] && { echo "$p"; return 0; }
  return 1
}

smart_find() {
  # Try exact, then variants (suffix swaps, char swaps, ext twins)
  local fname="$1" album="$2" root="$3"
  local base="${fname%.*}" ext="${fname##*.}" lowbase lowfname cand
  # 1) exact/ci
  if cand="$(find_one "$fname" "$album" "$root")"; then echo "$cand"; return 0; fi
  # 2) case/char swaps on whole name
  while IFS= read -r v; do
    if cand="$(find_one "$v" "$album" "$root")"; then echo "$cand"; return 0; fi
  done < <(swap_chars_variants "$fname")

  # 3) suffix-stripped base + ext variants
  while IFS= read -r sb; do
    while IFS= read -r nm; do
      if cand="$(find_one "$nm" "$album" "$root")"; then echo "$cand"; return 0; fi
    done < <(try_ext_variants "$sb" "$ext")
    # also try with space/_/- swaps on the base
    while IFS= read -r bv; do
      while IFS= read -r nm; do
        if cand="$(find_one "$nm" "$album" "$root")"; then echo "$cand"; return 0; fi
      done < <(try_ext_variants "$bv" "$ext")
    done < <(swap_chars_variants "$sb")
  done < <(strip_suffix_variants "$base")

  # 4) lowercased base/whole (helps IMG_0001.JPG vs img_0001.jpg)
  lowbase="$(printf "%s" "$base" | tr '[:upper:]' '[:lower:]')"
  lowfname="${lowbase}.$(printf "%s" "$ext" | tr '[:upper:]' '[:lower:]')"
  if cand="$(find_one "$lowfname" "$album" "$root")"; then echo "$cand"; return 0; fi
  while IFS= read -r nm; do
    if cand="$(find_one "$nm" "$album" "$root")"; then echo "$cand"; return 0; fi
  done < <(try_ext_variants "$lowbase" "$(printf "%s" "$ext" | tr '[:upper:]' '[:lower:]')")

  return 1
}

album_wanted() {
  local name="$1"
  [[ ${#REMAIN_FILTER[@]} -eq 0 ]] && return 0
  local a; for a in "${REMAIN_FILTER[@]}"; do [[ "$name" == "$a" ]] && return 0; done
  return 1
}

shopt -s nullglob
for mf in "$ALBUM_DIFF_DIR"/*__missing.txt; do
  base="$(basename "$mf")"
  ente_album="${base%%__VS__*}"
  immich_album="${base#*__VS__}"; immich_album="${immich_album%__missing.txt}"
  album_wanted "$immich_album" || continue

  echo "== $ente_album  →  $immich_album =="
  while IFS= read -r fname || [[ -n "$fname" ]]; do
    [[ -z "$fname" ]] && continue
    if fpath="$(smart_find "$fname" "$ente_album" "$ENTE_ROOT")"; then
      echo "  + $fname"
      immich upload --album "$immich_album" "$fpath"
    else
      echo "  ! NOT FOUND in Ente export (after heuristics): $fname"
    fi
  done < "$mf"
done

echo "Done."
