#!/usr/bin/env bash
# backfill_from_ente_missing_v7.sh
# Robust “find by filename (with -edited fallback) and add to Immich album” sweep
# Fixes: unbound $orig, blank lines, CRLF inputs, and arg counting in functions.

set -euo pipefail

ENTE_ROOT=""
DIFF_DIR="album_diffs"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ente-root) ENTE_ROOT="${2:-}"; shift 2 ;;
    --diff-dir)  DIFF_DIR="${2:-}";  shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$ENTE_ROOT" && -d "$ENTE_ROOT" ]] || { echo "Usage: $0 --ente-root /path --diff-dir album_diffs" >&2; exit 2; }

echo "Backfill from Ente → Immich"
echo "  ENTE_ROOT : $ENTE_ROOT"
echo "  DIFF_DIR  : $DIFF_DIR"
echo "  DRY_RUN   : ${DRY_RUN-}"
echo

shopt -s nullglob

# ---------- helpers ----------
norm_stem(){ local n="${1,,}"; n="${n%.*}"; n="${n//[^a-z0-9]/}"; printf '%s' "$n"; }
has_edited(){ [[ "${1,,}" == *"-edited."* || "${1,,}" == *"-edited-edited."* ]]; }
drop_edited_suffix(){
  # drop last '-edited' (or '-edited-edited') before extension
  local lc="${1,,}"
  if [[ "$lc" =~ ^(.+)-edited(\.[^.]+)$ ]]; then
    printf '%s%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  elif [[ "$lc" =~ ^(.+)-edited-edited(\.[^.]+)$ ]]; then
    printf '%s%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  else
    printf '%s' "$1"
  fi
}
file_base_noext(){
  local fn="${1##*/}"
  echo "${fn%.*}"
}

find_exact_in(){
  # $1=dir  $2=filename (case-insensitive)
  local dir="${1:-}" name="${2:-}"
  [[ -n "$dir" && -n "$name" ]] || { echo ""; return; }
  /usr/bin/find "$dir" -type f -iname "$name" -print -quit 2>/dev/null || true
}

find_exact_any_ext_in(){
  # $1=dir  $2=basename-without-ext (case-insensitive)
  local dir="${1:-}" base="${2:-}"
  [[ -n "$dir" && -n "$base" ]] || { echo ""; return; }
  /usr/bin/find "$dir" -type f -print 2>/dev/null \
  | awk -v b="$(echo "$base" | tr '[:upper:]' '[:lower:]')" '
      { fn=$0; t=tolower(fn); gsub(/^.*\//,"",t);
        n=t; sub(/\.[^.]+$/,"",n);
        if (n==b) { print fn; exit } }' | head -n1
}

find_loose_in(){
  # $1=dir  $2=normalized-stem (letters+digits only)
  local dir="${1:-}" stem="${2:-}"
  [[ -n "$dir" && -n "$stem" ]] || { echo ""; return; }
  /usr/bin/find "$dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.heic" \) -print 2>/dev/null \
  | awk -v s="$stem" '{
      t=tolower($0); gsub(/^.*\//,"",t); sub(/\.[^.]+$/,"",t); gsub(/[^a-z0-9]/,"",t);
      if (t==s) { print $0; exit } }' | head -n1
}

try_candidates(){
  # $1=search_dir  $2=original filename (with ext)
  local dir="${1:-}" orig="${2-}"
  [[ -n "$dir" && -n "${orig-}" ]] || { echo ""; return; }

  local lc="${orig,,}"
  local base_noext="$(file_base_noext "$lc")"
  local fpath=""

  # 1) exact
  fpath="$(find_exact_in "$dir" "$orig")"
  [[ -n "$fpath" ]] && { echo "$fpath"; return; }

  # 2) edited <-> base swap (any ext)
  if has_edited "$lc"; then
    local base_swap="$(file_base_noext "$(drop_edited_suffix "$lc")")"
    fpath="$(find_exact_any_ext_in "$dir" "$base_swap")"
  else
    fpath="$(find_exact_any_ext_in "$dir" "${base_noext}-edited")"
    [[ -z "$fpath" ]] && fpath="$(find_exact_any_ext_in "$dir" "${base_noext}-edited-edited")"
  fi
  [[ -n "$fpath" ]] && { echo "$fpath"; return; }

  # 3) loose stem
  local stem="$(norm_stem "$orig")"
  fpath="$(find_loose_in "$dir" "$stem")"
  [[ -n "$fpath" ]] && { echo "$fpath"; return; }

  # 4) loose with edited/base swap
  if has_edited "$lc"; then
    local base_stem="$(norm_stem "$(drop_edited_suffix "$lc")")"
    fpath="$(find_loose_in "$dir" "$base_stem")"
  else
    local e1="$(norm_stem "${base_noext}-edited")"
    local e2="$(norm_stem "${base_noext}-edited-edited")"
    fpath="$(find_loose_in "$dir" "$e1")"
    [[ -z "$fpath" ]] && fpath="$(find_loose_in "$dir" "$e2")"
  fi
  [[ -n "$fpath" ]] && { echo "$fpath"; return; }

  echo ""
}

immich_add(){
  local album="${1:-}" f="${2:-}"
  [[ -n "$album" && -n "$f" ]] || return 0
  if [[ -n "${DRY_RUN-}" ]]; then
    echo "    (dry-run) immich upload --album \"$album\" \"$f\""
  else
    immich upload --album "$album" "$f"
  fi
}

# ---------- main ----------
found_total=0; missing_total=0; uploaded_total=0

lists=( "$DIFF_DIR"/*__missing.txt )
if [[ ${#lists[@]} -eq 1 && ! -f "${lists[0]}" ]]; then
  echo "No missing-list files found in: $DIFF_DIR"; exit 0
fi

for mf in "${lists[@]}"; do
  base="$(basename "$mf")"
  # trim CR from filename lines inside the file
  ente_album="${base%%__VS__*}"
  immich_album="${base#*__VS__}"; immich_album="${immich_album%__missing.txt}"

  # prefer the album folder; fallback to whole export
  search_dir="$ENTE_ROOT/$ente_album"; [[ -d "$search_dir" ]] || search_dir="$ENTE_ROOT"

  echo "== $ente_album  →  $immich_album =="

  # read list; strip CR and skip blanks
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    fname="${raw%$'\r'}"
    [[ -z "$fname" ]] && continue

    # First try in album dir, then global export
    fpath="$(try_candidates "$search_dir" "$fname")"
    [[ -z "$fpath" ]] && fpath="$(try_candidates "$ENTE_ROOT" "$fname")"

    if [[ -n "$fpath" ]]; then
      echo "  + FOUND: $fname  ->  $fpath"
      found_total=$((found_total+1))
      immich_add "$immich_album" "$fpath"
      [[ -z "${DRY_RUN-}" ]] && uploaded_total=$((uploaded_total+1))
    else
      echo "  ! NOT FOUND: $fname"
      missing_total=$((missing_total+1))
    fi
  done < "$mf"
done

echo
echo "=== Summary ==="
echo "  files found in Ente : $found_total"
echo "  files not found     : $missing_total"
if [[ -n "${DRY_RUN-}" ]]; then
  echo "  (dry-run) would upload: $found_total"
else
  echo "  actually uploaded     : $uploaded_total"
fi

