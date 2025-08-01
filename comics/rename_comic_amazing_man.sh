#!/bin/bash
COMIC_DIR="$HOME/Desktop/Amazing-Man-Comics"
cd "$COMIC_DIR" || exit 1

for f in Amazing-Man-Comics-*.{cbz,cbr}; do
  [[ -f "$f" ]] || continue

  ext="${f##*.}"

  # Extract issue and year from the name
  issue=$(echo "$f" | grep -oP '(?<=Amazing-Man-Comics-)[0-9]+')
  year=$(echo "$f" | grep -oP '([0-9]{4})(?=\.'$ext')')

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

