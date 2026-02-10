#!/bin/bash
# make_it_green.sh - Full Ente-to-Immich Reconciliation Pipeline
#
# Runs the complete reconciliation workflow:
#   1. Normalizes line endings in album diff files
#   2. Runs backfill_remaining.sh to upload missing files
#   3. Re-dumps Immich albums
#   4. Re-compares Ente vs Immich (both strict and loose matching)
#   5. Prints summary of remaining gaps
#
# Usage:
#   export IMMICH_API_KEY="your-key"
#   ./make_it_green.sh
#
# Prerequisites: python3, immich CLI, backfill_remaining.sh in same directory
set -euo pipefail

ENTE_JSON="/Users/michal/Downloads/Ente Photos/export_status.json"
IMMICH_JSON="immich_albums_detailed.json"
MAP="album_map.csv"
SKIP="skip_ente.txt"

echo ">>> Step 1: normalize CRLF endings in album_diffs/"
if compgen -G "album_diffs/*__missing.txt" > /dev/null; then
  for f in album_diffs/*__missing.txt; do
    sed -i '' $'s/\r$//' "$f"
  done
fi

echo ">>> Step 2: run backfill (not a dry-run)"
if [ -x backfill_remaining.sh ]; then
  bash backfill_remaining.sh
else
  echo "WARNING: backfill_remaining.sh not found or not executable"
fi

echo ">>> Step 3: regenerate Immich album dump"
python3 dump_immich_albums_detailed.py

echo ">>> Step 4: re-compare (strict)"
python3 compare_ente_to_immich.py \
  --ente "$ENTE_JSON" \
  --immich "$IMMICH_JSON" \
  --map "$MAP" \
  --skip-ente "$SKIP" \
  --out album_comparison_strict.csv

echo ">>> Step 5: re-compare (loose)"
python3 compare_ente_to_immich.py \
  --ente "$ENTE_JSON" \
  --immich "$IMMICH_JSON" \
  --map "$MAP" \
  --skip-ente "$SKIP" \
  --out album_comparison.csv \
  --loose

echo ">>> Step 6: summary of remaining gaps"
echo -n "Strict missing total: "
awk -F, 'NR>1{s+=$5}END{print s}' album_comparison_strict.csv
echo -n "Loose missing total: "
awk -F, 'NR>1{s+=$5}END{print s}' album_comparison.csv

echo ">>> Done. Check album_diffs/ if any remain."

