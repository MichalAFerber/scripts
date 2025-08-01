#!/bin/bash
# Folder containing your comics
COMIC_DIR="$HOME/Desktop/Amazing-Man-Comics"

cd "$COMIC_DIR" || exit 1

# Loop through all cbz/cbr files
for f in *.{cbz,cbr}; do
  [[ -f "$f" ]] || continue  # skip if no files match

  # Extract details from filename
  # Example filename: Amazing-Man Comics #005 (1939).cbz
  series="Amazing-Man Comics"
  issue=$(echo "$f" | grep -oP '#\K[0-9]+')
  year=$(echo "$f" | grep -oP '\(\K[0-9]{4}(?=\))')
  ext="${f##*.}"
  base="${f%.*}"

  # Create ComicInfo.xml
  xml_file="${base}_ComicInfo.xml"
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

