#!/opt/homebrew/bin/bash
# add-book.sh — Add PDF/EPUB books to Yoda Bookshelf + Obsidian-Master
set -o pipefail

# ── Config ──────────────────────────────────────────────────────────────
BOOKSHELF="/Volumes/Yoda/Bookshelf"
INBOX="$BOOKSHELF/_Inbox"
OBSIDIAN_BOOKS="/Users/michal/Obsidian/Obsidian-Master/books"
COVERS_DIR="$OBSIDIAN_BOOKS/covers"

PDF_CATEGORIES=("America" "Business" "Classic Fiction" "Conspiracy" "Esoteric" "For Dummies" "Gaming" "Health" "Reference" "Religion" "Technology")
EPUB_CATEGORIES=("Classic Fiction" "Humor" "Political Fiction" "Technology" "Xtra")

declare -A GENRE_MAP
GENRE_MAP["America"]="Politics & Government"
GENRE_MAP["Business"]="Business"
GENRE_MAP["Classic Fiction"]="Classic Fiction"
GENRE_MAP["Conspiracy"]="Conspiracy"
GENRE_MAP["Esoteric"]="Esoteric & Occult"
GENRE_MAP["For Dummies"]="For Dummies"
GENRE_MAP["Gaming"]="Gaming"
GENRE_MAP["Health"]="Health & Wellness"
GENRE_MAP["Reference"]="Reference"
GENRE_MAP["Religion"]="Religion & Theology"
GENRE_MAP["Technology"]="Technology"
GENRE_MAP["Humor"]="Humor"
GENRE_MAP["Political Fiction"]="Political Fiction"
GENRE_MAP["Xtra"]="Adult Fiction"

DRY_RUN=false
INTERACTIVE=false
ADDED=()
ERRORS=()

# ── Functions ───────────────────────────────────────────────────────────

usage() {
  cat <<'USAGE'
Usage: add-book.sh [--dry-run] [--interactive] [file1.pdf|epub ...]

Adds books to Yoda Bookshelf and creates Obsidian notes.

If no files are given, processes all PDF/EPUB files in the Bookshelf
inbox: /Volumes/Yoda/Bookshelf/_Inbox/ (including subdirectories)

Options:
  --dry-run       Show what would happen without making changes
  --interactive   Prompt for title, author, edition, and category
  --help          Show this help
USAGE
  exit 0
}

die() { echo "ERROR: $*" >&2; }

sanitize_text() {
  # Strip non-ASCII and non-printable characters, collapse whitespace
  printf '%s' "$1" | perl -CS -pe 's/[^\x20-\x7E]//g; s/\s+/ /g; s/^\s+|\s+$//g'
}

clean_title() {
  # Fix common filename-to-title issues
  local t="$1"
  # Remove trailing junk like lone ) , or :
  t=$(echo "$t" | sed 's/[),:]*$//')
  # Split CamelCase (GetStartedArduino -> Get Started Arduino)
  t=$(echo "$t" | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g')
  # Remove "Small" suffix (scan artifacts)
  t=$(echo "$t" | sed 's/ Small$//')
  # Known title fixups
  declare -A TITLE_MAP
  TITLE_MAP["Pi-Projects5"]="The Official Raspberry Pi Projects Book (Vol. 5)"
  TITLE_MAP["Projects Book v1"]="The Official Raspberry Pi Projects Book (Vol. 1)"
  TITLE_MAP["Projects Book v2"]="The Official Raspberry Pi Projects Book (Vol. 2)"
  TITLE_MAP["Projects Book v3"]="The Official Raspberry Pi Projects Book (Vol. 3)"
  TITLE_MAP["Projects Book v4"]="The Official Raspberry Pi Projects Book (Vol. 4)"
  TITLE_MAP["Handbook-2023"]="The Official Raspberry Pi Handbook 2023"
  TITLE_MAP["Get Started Arduino"]="Get Started with Arduino"
  TITLE_MAP["Media Player"]="Build a Raspberry Pi Media Player"
  TITLE_MAP["MediaPlayer"]="Build a Raspberry Pi Media Player"
  TITLE_MAP["Computers that made Britain v1"]="The Computers that Made Britain"
  for key in "${!TITLE_MAP[@]}"; do
    if [[ "$t" == "$key" ]]; then
      echo "${TITLE_MAP[$key]}"
      return
    fi
  done
  # Collapse whitespace, trim
  t=$(echo "$t" | sed 's/  */ /g; s/^ *//; s/ *$//')
  echo "$t"
}

sanitize_filename() {
  local name="$1"
  name=$(echo "$name" | sed 's/[\/\\:?*<>|]//g; s/  */ /g; s/^ *//; s/ *$//')
  echo "${name:0:120}"
}

prompt_field() {
  local label="$1" default="$2" result
  read -r -p "  $label [$default]: " result </dev/tty
  echo "${result:-$default}"
}

choose_category() {
  local format="$1"
  local -n cats="$2"
  echo "  Available categories:" >/dev/tty
  for i in "${!cats[@]}"; do
    printf "    %2d) %s\n" "$((i+1))" "${cats[$i]}" >/dev/tty
  done
  local choice
  read -r -p "  Category [number or name]: " choice </dev/tty
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#cats[@]} )); then
    echo "${cats[$((choice-1))]}"
  else
    for c in "${cats[@]}"; do
      [[ "$c" == "$choice" ]] && { echo "$c"; return; }
    done
    echo "$choice"
  fi
}

auto_classify() {
  local title_lower
  title_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  local format_lower
  format_lower=$(echo "$2" | tr '[:upper:]' '[:lower:]')

  # Check keywords in priority order
  if [[ "$title_lower" =~ "for dummies" ]]; then
    echo "For Dummies"; return
  fi
  if [[ "$title_lower" =~ (arduino|raspberry|python|programming|computer|electronics|gpio|wearable|maker|making|handbook|beginner|projects|media\ player|pi-project|tech|circuit|robot|microcontroller|linux|code|coding|unplugged) ]]; then
    echo "Technology"; return
  fi
  if [[ "$title_lower" =~ (game|gaming) ]]; then
    if [[ "$format_lower" == "pdf" ]]; then
      echo "Gaming"; return
    fi
  fi
  if [[ "$title_lower" =~ (health|medical|wellness|fitness|diet|nutrition) ]]; then
    echo "Health"; return
  fi
  if [[ "$title_lower" =~ (business|entrepreneur|management|marketing|finance|economics|money) ]]; then
    echo "Business"; return
  fi
  if [[ "$title_lower" =~ (america|politic|government|constitution|democrat|republican|liberty|freedom) ]]; then
    echo "America"; return
  fi
  if [[ "$title_lower" =~ (bible|religion|theology|spiritual|church|faith|prayer|god|jesus|christian) ]]; then
    echo "Religion"; return
  fi
  if [[ "$title_lower" =~ (conspiracy|secret|hidden|illuminat|deep\ state) ]]; then
    echo "Conspiracy"; return
  fi
  if [[ "$title_lower" =~ (esoteric|occult|mystic|alchemy|hermetic|kabbalah|tarot) ]]; then
    echo "Esoteric"; return
  fi
  if [[ "$title_lower" =~ (dictionary|encyclopedia|almanac|manual|reference|guide) ]]; then
    echo "Reference"; return
  fi
  if [[ "$format_lower" == "epub" ]]; then
    if [[ "$title_lower" =~ (humor|funny|comedy|joke|laugh|satire) ]]; then
      echo "Humor"; return
    fi
    if [[ "$title_lower" =~ (political\ fiction) ]]; then
      echo "Political Fiction"; return
    fi
    if [[ "$title_lower" =~ (novel|fiction|story|stories|tale) ]]; then
      echo "Classic Fiction"; return
    fi
  fi
  if [[ "$format_lower" == "pdf" ]]; then
    if [[ "$title_lower" =~ (novel|fiction|story|stories|tale) ]]; then
      echo "Classic Fiction"; return
    fi
  fi
  # Default
  echo "Technology"
}

extract_pdf_metadata() {
  local file="$1"
  local info
  info=$(pdfinfo "$file" 2>/dev/null || true)
  PDF_META_TITLE=$(echo "$info" | grep -ai "^Title:" | sed 's/^Title: *//' | perl -pe 's/[^\x20-\x7E]//g; s/\s+/ /g; s/^\s+|\s+$//g' || true)
  PDF_META_AUTHOR=$(echo "$info" | grep -ai "^Author:" | sed 's/^Author: *//' | perl -pe 's/[^\x20-\x7E]//g; s/\s+/ /g; s/^\s+|\s+$//g' || true)

  # If author is still empty, try pdftotext first pages for publisher/author clues
  if [[ -z "$PDF_META_AUTHOR" ]]; then
    local first_pages
    first_pages=$(pdftotext "$file" - -f 1 -l 8 2>/dev/null | head -200 || true)
    if echo "$first_pages" | grep -qi "raspberry pi\|from the makers of.*magpi\|from the makers of.*hackspace\|raspberry pi press"; then
      PDF_META_AUTHOR="Raspberry Pi Press"
    elif echo "$first_pages" | grep -qi "for dummies"; then
      local by_author
      by_author=$(echo "$first_pages" | grep -oi "by [A-Z][a-z]* [A-Z][a-z]*" | head -1 | sed 's/^by //' || true)
      [[ -n "$by_author" ]] && PDF_META_AUTHOR="$by_author"
    else
      local by_author
      by_author=$(echo "$first_pages" | grep -oi "by [A-Z][a-z]* [A-Z][a-z]*" | head -1 | sed 's/^by //' || true)
      [[ -n "$by_author" ]] && PDF_META_AUTHOR="$by_author"
    fi
    # Title-based publisher fallback for known patterns
    if [[ -z "$PDF_META_AUTHOR" ]]; then
      local fn_lower
      fn_lower=$(echo "$(basename "$file")" | tr '[:upper:]' '[:lower:]')
      if [[ "$fn_lower" =~ (raspberry|magpi|hackspace|pi-project|wearable.tech|book.of.making|unplugged|gpio|projects.book|getstartedarduino|media.?player) ]]; then
        PDF_META_AUTHOR="Raspberry Pi Press"
      fi
    fi
  fi
}

extract_epub_metadata() {
  local file="$1"
  python3 - "$file" << 'PYEOF'
import zipfile, xml.etree.ElementTree as ET, sys

try:
    filepath = sys.argv[1]
    with zipfile.ZipFile(filepath) as zf:
        container = ET.fromstring(zf.read('META-INF/container.xml'))
        ns = {'c': 'urn:oasis:names:tc:opendocument:xmlns:container'}
        opf_path = container.find('.//c:rootfile', ns).get('full-path')
        opf = ET.fromstring(zf.read(opf_path))
        dc = 'http://purl.org/dc/elements/1.1/'
        title_el = opf.find(f'.//{{{dc}}}title')
        author_el = opf.find(f'.//{{{dc}}}creator')
        title = title_el.text if title_el is not None and title_el.text else ''
        author = author_el.text if author_el is not None and author_el.text else ''
        print(f'TITLE={title}')
        print(f'AUTHOR={author}')
except Exception as e:
    print('TITLE=', file=sys.stdout)
    print('AUTHOR=', file=sys.stdout)
PYEOF
}

parse_filename_metadata() {
  local basename="$1"
  basename="${basename%.*}"  # strip extension
  # Clean up underscores to spaces
  basename="${basename//_/ }"
  if [[ "$basename" == *" - "* ]]; then
    FN_TITLE="${basename% - *}"
    FN_AUTHOR="${basename##* - }"
  else
    FN_TITLE="$basename"
    FN_AUTHOR=""
  fi
}

extract_edition_from_title() {
  # Extract edition info from title, return "title|edition"
  local title="$1"
  local edition=""
  local re_ed='([0-9]+(st|nd|rd|th)? ?(ed|edition|Edition|Ed))'
  local re_shortedition='([0-9]+(ed|Ed))'
  local re_paren='\(([^)]*[Ee]dition[^)]*)\)'
  if [[ "$title" =~ $re_shortedition ]]; then
    local raw="${BASH_REMATCH[1]}"
    local num="${raw%%[eE]*}"
    edition="${num}${num: -1}$(echo "${raw}" | sed 's/^[0-9]*//')"
    # Normalize: "2ed" -> "2nd Edition"
    case "$num" in
      1) edition="1st Edition" ;; 2) edition="2nd Edition" ;; 3) edition="3rd Edition" ;;
      *) edition="${num}th Edition" ;;
    esac
    title="${title/$raw/}"
    title=$(echo "$title" | sed 's/  */ /g; s/^ *//; s/ *$//')
  elif [[ "$title" =~ $re_ed ]]; then
    edition="${BASH_REMATCH[1]}"
    title="${title/$edition/}"
    title=$(echo "$title" | sed 's/  */ /g; s/^ *//; s/ *$//')
  elif [[ "$title" =~ $re_paren ]]; then
    edition="${BASH_REMATCH[1]}"
    title="${title/(${edition})/}"
    title=$(echo "$title" | sed 's/  */ /g; s/^ *//; s/ *$//')
  fi
  # Clean trailing punctuation left after edition removal
  title=$(echo "$title" | sed 's/[,;: ]*$//')
  echo "${title}|${edition}"
}

extract_pdf_cover() {
  local pdf="$1" output="$2"
  pdftoppm -f 1 -l 1 -jpeg -r 300 -singlefile "$pdf" "${output%.jpg}" 2>/dev/null
}

extract_epub_cover() {
  local epub="$1" output="$2"
  python3 - "$epub" "$output" << 'PYEOF'
import zipfile, xml.etree.ElementTree as ET, os, sys

try:
    epub_path = sys.argv[1]
    output_path = sys.argv[2]
    with zipfile.ZipFile(epub_path) as zf:
        container = ET.fromstring(zf.read('META-INF/container.xml'))
        ns_c = {'c': 'urn:oasis:names:tc:opendocument:xmlns:container'}
        opf_path = container.find('.//c:rootfile', ns_c).get('full-path')
        opf_dir = os.path.dirname(opf_path)
        opf = ET.fromstring(zf.read(opf_path))
        ns_opf = 'http://www.idpf.org/2007/opf'

        cover_id = None
        for meta in opf.findall(f'.//{{{ns_opf}}}meta'):
            if meta.get('name') == 'cover':
                cover_id = meta.get('content')
                break

        if not cover_id:
            for item in opf.findall(f'.//{{{ns_opf}}}item'):
                if 'cover-image' in (item.get('properties') or ''):
                    cover_id = item.get('id')
                    break

        if not cover_id:
            for item in opf.findall(f'.//{{{ns_opf}}}item'):
                if 'cover' in (item.get('id') or '').lower():
                    cover_id = item.get('id')
                    break

        if cover_id:
            for item in opf.findall(f'.//{{{ns_opf}}}item'):
                if item.get('id') == cover_id:
                    href = item.get('href')
                    img_path = os.path.join(opf_dir, href) if opf_dir else href
                    img_path = os.path.normpath(img_path)
                    data = zf.read(img_path)
                    with open(output_path, 'wb') as f:
                        f.write(data)
                    print('OK')
                    sys.exit(0)
        print('NO_COVER')
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    print('NO_COVER')
PYEOF
}

md5_file() {
  md5 -q "$1" 2>/dev/null || md5sum "$1" 2>/dev/null | awk '{print $1}'
}

process_book() {
  local filepath="$1"
  local filename ext ext_lower format

  filename=$(basename "$filepath")
  ext="${filename##*.}"
  ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

  if [[ "$ext_lower" != "pdf" && "$ext_lower" != "epub" ]]; then
    die "Unsupported file type: $filename (only PDF and EPUB)"
    ERRORS+=("$filename: unsupported file type")
    return
  fi

  format=$(echo "$ext_lower" | tr '[:lower:]' '[:upper:]')
  echo ""
  echo "Processing: $filename"

  # ── Extract metadata ──
  local meta_title="" meta_author=""
  parse_filename_metadata "$filename"

  if [[ "$ext_lower" == "pdf" ]]; then
    extract_pdf_metadata "$filepath"
    meta_title="${PDF_META_TITLE:-$FN_TITLE}"
    meta_author="${PDF_META_AUTHOR:-$FN_AUTHOR}"
  else
    local epub_meta
    epub_meta=$(extract_epub_metadata "$filepath")
    meta_title=$(echo "$epub_meta" | grep "^TITLE=" | sed 's/^TITLE=//')
    meta_author=$(echo "$epub_meta" | grep "^AUTHOR=" | sed 's/^AUTHOR=//')
  fi

  # Clean non-printable/non-ASCII characters from metadata
  meta_title=$(sanitize_text "$meta_title")
  meta_author=$(sanitize_text "$meta_author")

  # Normalize known publisher variants to "Raspberry Pi Press"
  if [[ "$meta_author" =~ [Mm]akers.of.*(MagPi|HackSpace|Raspberry\ Pi) ]]; then
    meta_author="Raspberry Pi Press"
  fi

  # Clean trailing punctuation from title
  meta_title=$(echo "$meta_title" | sed 's/[,;:]*$//')

  # Prefer non-empty values; filename parse as fallback
  [[ -z "$meta_title" ]] && meta_title="$FN_TITLE"
  [[ -z "$meta_author" ]] && meta_author="$FN_AUTHOR"
  [[ -z "$meta_title" ]] && meta_title="${filename%.*}"

  # Title-based author fallback for EPUBs with no author
  if [[ -z "$meta_author" ]]; then
    local title_lower
    title_lower=$(echo "$meta_title" | tr '[:upper:]' '[:lower:]')
    if [[ "$title_lower" =~ (raspberry|magpi|hackspace|pi-project|wearable.tech|book.of.making|unplugged|gpio|projects.book|arduino|media.?player) ]]; then
      meta_author="Raspberry Pi Press"
    fi
  fi
  [[ -z "$meta_author" ]] && meta_author="Unknown"

  # Clean up title and extract edition
  meta_title=$(clean_title "$meta_title")
  local title_edition
  title_edition=$(extract_edition_from_title "$meta_title")
  meta_title="${title_edition%%|*}"
  local meta_edition="${title_edition##*|}"

  echo "  Detected -- Title: $meta_title | Author: $meta_author"
  [[ -n "$meta_edition" ]] && echo "  Detected -- Edition: $meta_edition"

  # ── Determine fields (auto or interactive) ──
  local title author edition category

  if $INTERACTIVE; then
    echo ""
    title=$(prompt_field "Title" "$meta_title")
    author=$(prompt_field "Author" "$meta_author")
    edition=$(prompt_field "Edition (blank for none)" "$meta_edition")
    echo ""
    if [[ "$ext_lower" == "pdf" ]]; then
      category=$(choose_category "$format" PDF_CATEGORIES)
    else
      category=$(choose_category "$format" EPUB_CATEGORIES)
    fi
  else
    title="$meta_title"
    author="$meta_author"
    edition="$meta_edition"
    category=$(auto_classify "$title" "$format")
  fi

  local genre="${GENRE_MAP[$category]:-$category}"

  # ── Build filenames ──
  local book_filename note_title
  if [[ -n "$edition" ]]; then
    book_filename="$title ($edition) - $author.$ext_lower"
    note_title="$title ($edition) - $author"
  else
    book_filename="$title - $author.$ext_lower"
    note_title="$title - $author"
  fi
  book_filename=$(sanitize_filename "$book_filename")
  note_title=$(sanitize_filename "$note_title")

  local target_dir="$BOOKSHELF/${format}s/$category"
  local target_path="$target_dir/$book_filename"
  local cover_name="$(sanitize_filename "$title - $author").jpg"
  local cover_path="$COVERS_DIR/$cover_name"
  local note_filename="${note_title}.md"
  local note_path="$OBSIDIAN_BOOKS/$note_filename"
  local relative_cover="books/covers/$cover_name"

  echo ""
  echo "  -- Summary --"
  echo "  Title:    $title"
  echo "  Author:   $author"
  [[ -n "$edition" ]] && echo "  Edition:  $edition"
  echo "  Category: $category"
  echo "  Genre:    $genre"
  echo "  Format:   $format"
  echo "  Bookshelf: $target_path"
  echo "  Cover:     $cover_path"
  echo "  Note:      $note_path"
  echo ""

  if $DRY_RUN; then
    echo "  [DRY RUN] No changes made."
    ADDED+=("$title - $author ($format) -> $category [dry run]")
    return
  fi

  # ── Checks ──
  if [[ ! -d "$target_dir" ]]; then
    die "Target directory does not exist: $target_dir"
    ERRORS+=("$filename: target directory missing -- $target_dir")
    return
  fi

  # Duplicate check (md5)
  local src_md5
  src_md5=$(md5_file "$filepath")
  local dup_found=false
  while IFS= read -r -d '' existing; do
    if [[ "$(md5_file "$existing")" == "$src_md5" ]]; then
      echo "  SKIP: Duplicate of existing file: $existing"
      ERRORS+=("$filename: duplicate of $existing")
      dup_found=true
      break
    fi
  done < <(find "$target_dir" -maxdepth 1 -name "*.$ext_lower" -print0 2>/dev/null)

  $dup_found && return

  # Filename collision
  if [[ -f "$target_path" ]]; then
    local base="${book_filename%.*}"
    local n=2
    while [[ -f "$target_dir/${base}_${n}.$ext_lower" ]]; do
      ((n++))
    done
    book_filename="${base}_${n}.$ext_lower"
    target_path="$target_dir/$book_filename"
    echo "  NOTE: Filename collision, using: $book_filename"
  fi

  # ── Extract cover (before move, so source file is still available) ──
  echo "  Extracting cover..."
  mkdir -p "$COVERS_DIR"
  if [[ "$ext_lower" == "pdf" ]]; then
    extract_pdf_cover "$filepath" "$cover_path"
    if [[ ! -f "$cover_path" ]]; then
      echo "  WARNING: Could not extract cover image"
    fi
  else
    local epub_result
    epub_result=$(extract_epub_cover "$filepath" "$cover_path")
    if [[ "$epub_result" != "OK" ]]; then
      echo "  WARNING: Could not extract cover image"
    fi
  fi

  # ── Move/Copy to Bookshelf ──
  local real_filepath
  real_filepath=$(cd "$(dirname "$filepath")" && pwd)/$(basename "$filepath")
  local real_inbox
  real_inbox=$(cd "$INBOX" 2>/dev/null && pwd) || real_inbox="$INBOX"
  local from_inbox=false
  [[ "$real_filepath" == "$real_inbox/"* ]] && from_inbox=true

  if $from_inbox; then
    echo "  Moving to bookshelf (from inbox)..."
    mv "$filepath" "$target_path"
  else
    echo "  Copying to bookshelf..."
    cp "$filepath" "$target_path"
  fi

  # ── Create Obsidian note ──
  echo "  Creating Obsidian note..."
  local edition_line=""
  [[ -n "$edition" ]] && edition_line="edition: \"$edition\""

  cat > "$note_path" <<NOTE
---
title: "$title"
author: "$author"
status: "Unread"
rating:
genre: "$genre"
format: "$format"
cover: "$relative_cover"
category: "$category"
${edition_line:+$edition_line
}date-started:
date-finished:
filepath: "$target_path"
tags:
  - book
---

# $title

**Author:** $author
**Genre:** $genre
**Format:** $format

## Notes

NOTE

  echo "  Done."
  ADDED+=("$title - $author ($format) -> $category")
}

# ── Main ────────────────────────────────────────────────────────────────

# Parse flags
files=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --interactive) INTERACTIVE=true ;;
    --help|-h) usage ;;
    *) files+=("$arg") ;;
  esac
done

# Check Yoda is mounted
if [[ ! -d "$BOOKSHELF" ]]; then
  echo "ERROR: Yoda Bookshelf not found at $BOOKSHELF"
  echo "Make sure the Yoda volume is mounted."
  exit 1
fi

# If no files given, scan the inbox (including subdirectories)
if [[ ${#files[@]} -eq 0 ]]; then
  if [[ ! -d "$INBOX" ]]; then
    echo "ERROR: Inbox not found at $INBOX"
    exit 1
  fi
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$INBOX" -type f \( -iname "*.pdf" -o -iname "*.epub" \) -print0 | sort -z)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "Inbox is empty -- nothing to process."
    exit 0
  fi
  echo "Found ${#files[@]} book(s) in inbox: $INBOX"
fi

$DRY_RUN && echo "-- DRY RUN MODE --"

# Process each file
for f in "${files[@]}"; do
  if [[ ! -f "$f" ]]; then
    die "File not found: $f"
    ERRORS+=("$f: file not found")
    continue
  fi
  process_book "$f"
done

# Clean up empty subdirectories in inbox
find "$INBOX" -mindepth 1 -type d -empty -delete 2>/dev/null || true

# ── Final Summary ──
echo ""
echo "========================================================================"
echo "  ADD BOOK COMPLETE"
echo "========================================================================"
printf "  Books added:   %-4d\n" "${#ADDED[@]}"
printf "  Errors:        %-4d\n" "${#ERRORS[@]}"
echo "========================================================================"

if [[ ${#ADDED[@]} -gt 0 ]]; then
  echo ""
  echo "Added:"
  for item in "${ADDED[@]}"; do
    echo "  + $item"
  done
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo ""
  echo "Errors:"
  for item in "${ERRORS[@]}"; do
    echo "  ! $item"
  done
fi
