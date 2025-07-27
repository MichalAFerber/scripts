#!/usr/bin/env bash
shopt -s nullglob

# Directories
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# Timestamped log file
timestamp=$(date +"%Y-%m-%d-%H%M")
LOG_FILE="$LOG_DIR/process_comics-$timestamp.txt"

# Options
DRY_RUN=false
REGEN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --regen)   REGEN=true ;;
  esac
done

log() {
  echo "$@" | tee -a "$LOG_FILE"
}

log "=== Run started at $(date) ==="

EXPECTED_REGEX='^.+ #[0-9]{3} \([0-9]{4}\)\.(cbz|cbr)$'

generate_comicinfo() {
  local file="$1"
  local base="${file%.*}"
  local series=$(echo "$base" | sed -E 's/ #.*//')
  local issue=$(echo "$base" | grep -oE '#[0-9]+' | tr -d '#')
  local year=$(echo "$base" | grep -oE '\([0-9]{4}\)' | tr -d '()')

  cat > ComicInfo.xml <<EOF
<ComicInfo>
  <Title>$series</Title>
  <Number>$issue</Number>
  <Year>$year</Year>
</ComicInfo>
EOF
}

is_zip_cbr() {
  local file="$1"
  if unzip -tq "$file" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

normalize_name() {
  local file="$1"
  local ext="$2"
  local name="${file%.*}"

  local year=$(echo "$name" | grep -oE '\([0-9]{4}\)' | head -n 1 | tr -d '()')
  [ -z "$year" ] && year="0000"

  local issue=$(echo "$name" | grep -oE '[0-9]{2,4}' | head -n 1)
  [ -z "$issue" ] && issue="001"

  local series=$(echo "$name" | sed -E "s/[\(\[].*//" | sed -E "s/[ _-]*${issue}.*//")
  series=$(echo "$series" | sed 's/[()]//g;s/  / /g' | xargs)

  echo "${series} #$(printf "%03d" "$issue") (${year})${ext}"
}

# Process a single file
process_file() {
  local file="$1"
  local ext=".${file##*.}"
  local dir=$(dirname "$file")
  local base=$(basename "$file")

  if [[ "$base" =~ $EXPECTED_REGEX ]] && [ "$REGEN" = false ]; then
    log "Skipping already formatted: $file"
    return
  fi

  if [[ "$base" =~ $EXPECTED_REGEX ]]; then
    if [[ "$ext" == ".cbz" && "$REGEN" = true ]]; then
      log "Re-embedding ComicInfo into: $file"
      $DRY_RUN || {
        generate_comicinfo "$base"
        (cd "$dir" && zip -j "$base" "$OLDPWD/ComicInfo.xml" >/dev/null)
        rm ComicInfo.xml
      }
    fi
    return
  fi

  new_name=$(normalize_name "$base" "$ext")
  new_path="$dir/$new_name"

  if [ "$DRY_RUN" = true ]; then
    log "Auto-cleaning: $file -> $new_path"
    return
  fi

  log "Auto-cleaning: $file -> $new_path"

  if [[ "$ext" == ".cbr" ]]; then
    if is_zip_cbr "$file"; then
      new_path="${new_path%.cbr}.cbz"
      log "Converting mislabeled ZIP-based CBR to CBZ: $file -> $new_path"
      tmpdir=$(mktemp -d)
      unzip -qq "$file" -d "$tmpdir"
      generate_comicinfo "$new_path"
      mv ComicInfo.xml "$tmpdir/"
      (cd "$tmpdir" && zip -qq -r "../$new_path" .)
      rm -rf "$tmpdir"
      rm "$file"
    else
      mv -n "$file" "$new_path"
    fi
  else
    mv -n "$file" "$new_path"
    generate_comicinfo "$new_path"
    (cd "$dir" && zip -j "$new_name" "$OLDPWD/ComicInfo.xml" >/dev/null)
    rm ComicInfo.xml
  fi
}

export -f log generate_comicinfo is_zip_cbr normalize_name process_file
export EXPECTED_REGEX DRY_RUN REGEN LOG_FILE

# Recursively find all cbz/cbr files and process
while IFS= read -r -d '' file; do
  process_file "$file"
done < <(find . -type f \( -iname "*.cbz" -o -iname "*.cbr" \) -print0)

log "=== Run finished at $(date) ==="
