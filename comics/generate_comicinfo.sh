#!/bin/bash
# generate_comicinfo.sh - Create ComicInfo.xml for Amazing-Man Comics
#
# Generates ComicInfo.xml metadata files for each CBZ/CBR in the target directory.
# For CBZ files, the XML is embedded directly into the archive. For CBR files,
# the XML is left alongside the file (CBR archives can't be safely modified).
#
# Usage:
#   cd ~/Desktop/Amazing-Man-Comics && bash generate_comicinfo.sh [--dry-run]
#
# Options:
#   --dry-run   Preview what would be created/embedded without making changes
#
# Expected filename format: "Amazing-Man Comics #005 (1939).cbz"
# The series name is hardcoded to "Amazing-Man Comics".

# Options
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

# Folder containing your comics
COMIC_DIR="$HOME/Desktop/Amazing-Man-Comics"

cd "$COMIC_DIR" || exit 1

# Loop through all cbz/cbr files
for f in *.{cbz,cbr}; do
  [[ -f "$f" ]] || continue  # skip if no files match

  # Extract details from filename
  # Example filename: Amazing-Man Comics #005 (1939).cbz
  series="Amazing-Man Comics"
  issue=$(echo "$f" | sed -n 's/.*#\([0-9]*\).*/\1/p')
  year=$(echo "$f" | sed -n 's/.*(\([0-9]\{4\}\)).*/\1/p')
  ext="${f##*.}"
  base="${f%.*}"

  xml_file="${base}_ComicInfo.xml"

  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would create $xml_file"
    if [[ "$ext" == "cbz" ]]; then
      echo "[DRY RUN] Would embed ComicInfo.xml into $f and remove $xml_file"
    else
      echo "[DRY RUN] Would leave $xml_file next to $f (CBR cannot be directly modified safely)"
    fi
    continue
  fi

  # Create ComicInfo.xml
  cat > "$xml_file" <<EOF
<?xml version="1.0"?>
<ComicInfo>
  <Title>$series #$issue</Title>
  <Series>$series</Series>
  <Number>$issue</Number>
  <Year>$year</Year>
  <Publisher>Centaur Publishing</Publisher>
  <LanguageISO>en</LanguageISO>
  <Summary>Amazing-Man Comics issue #$issue ($year)</Summary>
</ComicInfo>
EOF

  echo "Created $xml_file"

  # Optionally embed ComicInfo.xml into CBZ files (not CBR)
  if [[ "$ext" == "cbz" ]]; then
    zip -j "$f" "$xml_file" >/dev/null
    echo "Embedded ComicInfo.xml into $f"
    rm "$xml_file"
  else
    # For CBR, leave the XML next to the file
    echo "Left ComicInfo.xml next to $f (CBR cannot be directly modified safely)"
  fi
done

echo "Done!"
