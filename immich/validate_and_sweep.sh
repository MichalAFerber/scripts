#!/usr/bin/env bash
# validate_and_sweep.sh - Dump, Compare, and Auto-Fill Immich from Ente Export
#
# End-to-end pipeline that:
#   1. Dumps all Immich albums (via dump_immich_albums_detailed.py)
#   2. Compares Ente vs Immich albums (via compare_ente_to_immich.py)
#   3. Sweeps missing files: finds them on local disk and uploads to Immich
#   4. Re-dumps and re-compares to verify progress
#
# Usage:
#   export IMMICH_API_KEY="your-key"
#   ./validate_and_sweep.sh
#
# Prerequisites: python3, immich CLI, curl, jq, awk
set -euo pipefail

# ----- CONFIG -----
ENTE_JSON="${ENTE_JSON:-/Users/michal/Downloads/Ente Photos/export_status.json}"
ENTE_ROOT="${ENTE_ROOT:-/Users/michal/Downloads/Ente Photos}"
MANDO_ROOT="${MANDO_ROOT:-/Volumes/Mando}"
IMMICH_JSON="${IMMICH_JSON:-immich_albums_detailed.json}"
MAP="${MAP:-album_map.csv}"
SKIP="${SKIP:-skip_ente.txt}"
OUT="${OUT:-album_comparison.csv}"
DIFF_DIR="${DIFF_DIR:-album_diffs}"

# Batches: albums with missing items will be processed; leave empty to process all
REMAIN_FILTER=( )

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing tool: $1" >&2; exit 1; }; }
need immich; need python3; need awk; need sed; need find; need sort; need uniq

say(){ printf "\n=== %s ===\n" "$*"; }

# Heuristic search for a filename: prefer album dir in ENTE_ROOT, then whole ENTE_ROOT, then MANDO_ROOT
smart_find_one() {
  local fname="$1" album="$2" p base ext alt cand
  base="${fname%.*}"; ext="${fname##*.}"

  # helper to search a root
  _search_root() {
    local root="$1" name="$2" r
    [[ -d "$root" ]] || return 1
    # exact
    r="$(/usr/bin/find "$root" -type f -name "$name" -print -quit 2>/dev/null || true)"; [[ -n "$r" ]] && { echo "$r"; return 0; }
    # case-insensitive
    r="$(/usr/bin/find "$root" -type f -iname "$name" -print -quit 2>/dev/null || true)"; [[ -n "$r" ]] && { echo "$r"; return 0; }
    return 1
  }

  # 1) album dir inside ENTE_ROOT
  if [[ -d "$ENTE_ROOT/$album" ]]; then
    _search_root "$ENTE_ROOT/$album" "$fname" && return 0
  fi
  # 2) whole ENTE_ROOT
  _search_root "$ENTE_ROOT" "$fname" && return 0
  # 3) common extension twins
  for alt in jpg jpeg JPG JPEG heic HEIC png PNG; do
    [[ "$alt" == "$ext" ]] && continue
    cand="${base}.${alt}"
    [[ -d "$ENTE_ROOT/$album" ]] && _search_root "$ENTE_ROOT/$album" "$cand" && return 0
    _search_root "$ENTE_ROOT" "$cand" && return 0
  done
  # 4) suffix cleanup (_mp, _edited, (1), -1)
  for suf in "_mp" "_edited" "_edit" ; do
    cand="${base%$suf}.${ext}"
    [[ "$cand" != "$fname" ]] && {
      [[ -d "$ENTE_ROOT/$album" ]] && _search_root "$ENTE_ROOT/$album" "$cand" && return 0
      _search_root "$ENTE_ROOT" "$cand" && return 0
    }
  done
  for suf in " (1)" " (2)" " (3)" "-1" "-2" "-3" ; do
    cand="${base%$suf}.${ext}"
    [[ "$cand" != "$fname" ]] && {
      [[ -d "$ENTE_ROOT/$album" ]] && _search_root "$ENTE_ROOT/$album" "$cand" && return 0
      _search_root "$ENTE_ROOT" "$cand" && return 0
    }
  done
  # 5) char swaps (space/_/-)
  for variant in \
    "$fname" \
    "${fname// /_}" "${fname// /-}" \
    "${fname//_/ }" "${fname//_/-}" \
    "${fname//-/_}" "${fname//-/ }"
  do
    [[ -d "$ENTE_ROOT/$album" ]] && _search_root "$ENTE_ROOT/$album" "$variant" && return 0
    _search_root "$ENTE_ROOT" "$variant" && return 0
  done
  # 6) as a last resort, search MANDO_ROOT (external drive)
  [[ -d "$MANDO_ROOT" ]] && _search_root "$MANDO_ROOT" "$fname" && return 0
  [[ -d "$MANDO_ROOT" ]] && for alt in jpg jpeg JPG JPEG heic HEIC png PNG; do
    [[ "$alt" == "$ext" ]] && continue
    cand="${base}.${alt}"
    _search_root "$MANDO_ROOT" "$cand" && return 0
  done

  return 1
}

dump_and_compare() {
  say "Dumping Immich albums"
  python3 dump_immich_albums_detailed.py

  say "Comparing Ente → Immich (one-way)"
  python3 compare_ente_to_immich.py \
    --ente "$ENTE_JSON" \
    --immich "$IMMICH_JSON" \
    --map "$MAP" \
    --skip-ente "$SKIP" \
    --out "$OUT" \
    --diff-dir "$DIFF_DIR"

  say "Summary"
  awk -F, 'NR>1{gsub(/\r/,"",$6); c[$6]++} END{for (k in c) printf "%s %d\n", k, c[k]}' "$OUT" | sort
}

sweep_missing() {
  say "Sweeping albums with missing items (direct upload into target Immich albums)"
  shopt -s nullglob
  for mf in "$DIFF_DIR"/*__missing.txt; do
    base="$(basename "$mf")"
    ente_album="${base%%__VS__*}"
    immich_album="${base#*__VS__}"; immich_album="${immich_album%__missing.txt}"

    # If filter is set, respect it
    if [[ ${#REMAIN_FILTER[@]} -gt 0 ]]; then
      want=0
      for a in "${REMAIN_FILTER[@]}"; do [[ "$immich_album" == "$a" ]] && { want=1; break; }; done
      [[ $want -eq 1 ]] || continue
    fi

    # skip if file is empty
    [[ -s "$mf" ]] || continue

    echo "-- $ente_album  →  $immich_album --"
    uploaded=0; notfound=0
    while IFS= read -r fname || [[ -n "$fname" ]]; do
      [[ -z "$fname" ]] && continue
      if fpath="$(smart_find_one "$fname" "$ente_album")"; then
        echo "  + $fname"
        immich upload --album "$immich_album" "$fpath" >/dev/null
        uploaded=$((uploaded+1))
      else
        echo "  ! NOT FOUND: $fname"
        notfound=$((notfound+1))
      fi
    done < "$mf"
    echo "  -> uploaded: $uploaded | still m

issing (unfound here): $notfound"
  done
}

# ---------- RUN ----------
dump_and_compare
sweep_missing
dump_and_compare
