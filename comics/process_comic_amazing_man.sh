#!/usr/bin/env bash
set -e

# process_comic_amazing_man.sh - Rename, Convert, and Tag Amazing-Man Comics
#
# Processes Amazing-Man Comics files:
#   1. Renames from "Amazing-Man-Comics-###-YYYY.ext" to "Amazing-Man Comics #001 (YYYY).ext"
#   2. Detects ZIP files mislabeled as .cbr and converts them to .cbz
#   3. Generates and embeds ComicInfo.xml metadata
#
# Usage:
#   bash process_comic_amazing_man.sh [--dry-run]
#
# Options:
#   --dry-run   Preview all actions without making changes

# Options
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

# Function: create ComicInfo.xml for a given issue/year
create_comicinfo() {
  local issue="$1"
  local year="$2"

  cat > ComicInfo.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<ComicInfo>
  <Series>Amazing-Man Comics</Series>
  <Number>${issue}</Number>
  <Year>${year}</Year>
  <LanguageISO>en</LanguageISO>
  <Publisher>Centaur Publications</Publisher>
  <Format>Digital</Format>
</ComicInfo>
EOF
}

# Function: embed ComicInfo.xml into archive
embed_metadata() {
  local filename="$1"
  local ext="${filename##*.}"

  if [[ "$ext" == "cbz" ]]; then
    zip -q "$filename" ComicInfo.xml
  elif [[ "$ext" == "cbr" ]]; then
    rar a -inul "$filename" ComicInfo.xml
  fi
}

# Detect if file is a ZIP misnamed as .cbr
is_zip_mislabeled() {
  local file="$1"
  # file -b --mime-type returns application/zip for zip files
  [[ "$(file -b --mime-type "$file")" == "application/zip" ]]
}

# Process all Amazing-Man files
for f in Amazing-Man-Comics-*; do
  [[ -f "$f" ]] || continue

  # Extract parts from filename: Amazing-Man-Comics-###-YYYY.ext
  if [[ "$f" =~ Amazing-Man-Comics-([0-9]+)-([0-9]{4})\.(cbz|cbr)$ ]]; then
    num="${BASH_REMATCH[1]}"
    year="${BASH_REMATCH[2]}"
    ext="${BASH_REMATCH[3]}"
    issue=$(printf "%03d" "$num")

    newname="Amazing-Man Comics #${issue} (${year}).${ext}"

    # Skip if already correct
    if [[ "$f" == "$newname" ]]; then
      echo "Skipping already processed: $f"
      continue
    fi

    if [ "$DRY_RUN" = true ]; then
      echo "[DRY RUN] Would rename: $f -> $newname"
      if [[ "$ext" == "cbr" ]] && is_zip_mislabeled "$f"; then
        echo "[DRY RUN] Would convert mislabeled ZIP (.cbr) -> .cbz: $newname -> ${newname%.cbr}.cbz"
        ext="cbz"
        newname="${newname%.cbr}.cbz"
      fi
      echo "[DRY RUN] Would generate and embed ComicInfo.xml into $newname"
      continue
    fi

    echo "Renaming: $f -> $newname"
    mv "$f" "$newname"
  else
    echo "Skipping unmatched file: $f"
    continue
  fi

  # Check for mislabeled .cbr files
  if [[ "$ext" == "cbr" ]] && is_zip_mislabeled "$newname"; then
    echo "Converting mislabeled ZIP (.cbr) -> .cbz: $newname"
    tmpdir=$(mktemp -d)
    unzip -qq "$newname" -d "$tmpdir"
    rm "$newname"
    (cd "$tmpdir" && zip -qr - .) > "${newname%.cbr}.cbz"
    rm -rf "$tmpdir"
    newname="${newname%.cbr}.cbz"
    ext="cbz"
  fi

  # Generate ComicInfo.xml and embed
  create_comicinfo "$issue" "$year"
  if [[ "$ext" == "cbr" ]]; then
    if ! rar t "$newname" &>/dev/null; then
      echo "ERROR: Bad archive $newname"
      continue
    fi
  fi
  embed_metadata "$newname"
done

rm -f ComicInfo.xml
echo "Done!"
