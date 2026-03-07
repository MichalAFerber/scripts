#!/usr/bin/env bash
set -euo pipefail
ENTE_ROOT="/Users/michal/Downloads/Ente Photos"
for mf in album_diffs/*__missing.txt; do
  base="$(basename "$mf")"
  ente_album="${base%%__VS__*}"
  immich_album="${base#*__VS__}"; immich_album="${immich_album%__missing.txt}"
  echo "== $ente_album  ->  $immich_album =="

  while IFS= read -r fname || [[ -n "$fname" ]]; do
    [[ -z "$fname" ]] && continue
    # find in matching folder first
    p=""; [[ -d "$ENTE_ROOT/$ente_album" ]] && p="$(/usr/bin/find "$ENTE_ROOT/$ente_album" -type f -name "$fname" -print -quit 2>/dev/null)"
    [[ -z "$p" ]] && [[ -d "$ENTE_ROOT/$ente_album" ]] && p="$(/usr/bin/find "$ENTE_ROOT/$ente_album" -type f -iname "$fname" -print -quit 2>/dev/null)"
    [[ -z "$p" ]] && p="$(/usr/bin/find "$ENTE_ROOT" -type f -name "$fname" -print -quit 2>/dev/null)"
    [[ -z "$p" ]] && p="$(/usr/bin/find "$ENTE_ROOT" -type f -iname "$fname" -print 2>/dev/null | head -n1)"
    if [[ -n "$p" ]]; then
      echo "  + $fname"
      immich upload --album "$immich_album" "$p"
    else
      echo "  ! NOT FOUND: $fname"
    fi
  done < "$mf"
done

