#!/bin/bash
# rename_comic_amazing_man.sh - Rename Amazing-Man Comic Files to Standard Format
#
# Renames files from "Amazing-Man-Comics-5-1939.cbz" format to the standard
# "Amazing-Man Comics #005 (1939).cbz" format with zero-padded issue numbers.
#
# Usage:
#   bash rename_comic_amazing_man.sh
#
# Source directory: $HOME/Desktop/Amazing-Man-Comics (hardcoded)
# Input pattern:   Amazing-Man-Comics-<issue>-<year>.<ext>
# Output pattern:  Amazing-Man Comics #<issue_padded> (<year>).<ext>

COMIC_DIR="$HOME/Desktop/Amazing-Man-Comics"
cd "$COMIC_DIR" || exit 1

for f in Amazing-Man-Comics-*.{cbz,cbr}; do
  [[ -f "$f" ]] || continue

  ext="${f##*.}"

  # Extract issue and year from the name
  issue=$(echo "$f" | sed -n 's/.*Amazing-Man-Comics-\([0-9]*\).*/\1/p')
  year=$(echo "$f" | sed -n 's/.*\([0-9]\{4\}\)\.'$ext'$/\1/p')

  # Zero-pad the issue
  issue_padded=$(printf "%03d" "$issue")

  newname="Amazing-Man Comics #${issue_padded} (${year}).${ext}"

  if [[ "$f" != "$newname" ]]; then
    echo "Renaming: $f -> $newname"
    mv "$f" "$newname"
  else
    echo "Skipping $f (already formatted)"
  fi
done

