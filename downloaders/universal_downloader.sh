#!/usr/bin/env bash
# universal_downloader.sh — YouTube / Rumble / TikTok / X / Telegram downloader
# - Single, interactive, or batch (.txt/.csv)
# - Optional output folder everywhere (default: $HOME/Downloads)
#
# Usage:
#   ./universal_downloader.sh
#   ./universal_downloader.sh <url> [filename] [folder]
#   ./universal_downloader.sh list.txt
#   ./universal_downloader.sh list.csv
#   ./universal_downloader.sh --dry-run <url> [filename] [folder]
#   ./universal_downloader.sh --dry-run list.txt
#
# TXT: each line = "url" OR "url,filename" OR "url,filename,folder"
# CSV: columns: url,filename,folder   (header optional; quotes OK if no embedded commas)
#
# Options:
#   --dry-run   Show what would be downloaded without actually downloading.
#
# Env:
#   YTDLP_BROWSER=chrome|firefox|brave|edge|chromium   (default for non-YouTube: chrome)
#   YTDLP_YT_BROWSER=safari|chrome|firefox|...         (default for YouTube: safari)
#   YTDLP_DEFAULT_DIR=/path/to/save                    (default: "$HOME/Downloads")
#   YTDLP_VERBOSE=1                                    (echo yt-dlp commands)

set -euo pipefail

DRY_RUN=false
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need yt-dlp

trim() { awk '{$1=$1;print}'; }
lower() { awk '{print tolower($0)}'; }

BROWSER_DEFAULT="${YTDLP_BROWSER:-chrome}"
BROWSER_YT="${YTDLP_YT_BROWSER:-safari}"
DEFAULT_DIR="${YTDLP_DEFAULT_DIR:-$HOME/Downloads}"

is_url()  { [[ "$1" =~ ^https?:// ]]; }
is_file() { [[ -f "$1" ]]; }

# Extract numeric status ID from X/Twitter URLs
extract_x_id() {
  local s="$1"
  if [[ "$s" =~ ([0-9]{10,}) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

detect_site_and_normalize() {
  local url="$1" site norm
  norm="$url"
  if [[ "$url" == *youtube.com* || "$url" == *youtu.be* ]]; then
    site="youtube"
  elif [[ "$url" == *rumble.com* ]]; then
    site="rumble"
  elif [[ "$url" == *tiktok.com* ]]; then
    site="tiktok"
  elif [[ "$url" == *twitter.com* || "$url" == *x.com* ]]; then
    site="x"
    if id="$(extract_x_id "$url")"; then
      norm="https://x.com/i/web/status/${id}"
    fi
  elif [[ "$url" == *t.me/* ]]; then
    site="telegram"
  else
    site="generic"
  fi
  printf '%s|%s' "$site" "$norm"
}

# -------- YouTube flow: Safari cookies -> Android (no cookies) -> iOS (no cookies)
download_youtube() {
  local url="$1"
  local outtpl="$2"

  # 1) Default client + Safari cookies (or override via YTDLP_YT_BROWSER)
  local base=( --cookies-from-browser "$BROWSER_YT" -o "$outtpl" --no-playlist -S "res,ext:mp4:m4a" )
  [[ -n "${YTDLP_VERBOSE:-}" ]] && echo "yt-dlp ${base[*]} \"$url\""
  if yt-dlp "${base[@]}" "$url"; then
    echo "   done (YouTube default client)"
    return 0
  fi

  echo "   SABR suspected; retrying with Android client (NO cookies)..."
  # 2) Android client, NO cookies (android doesn't support cookies)
  local android=( --extractor-args "youtube:player_client=android" -o "$outtpl" --no-playlist -S "res,ext:mp4:m4a" )
  [[ -n "${YTDLP_VERBOSE:-}" ]] && echo "yt-dlp ${android[*]} \"$url\""
  if yt-dlp "${android[@]}" "$url"; then
    echo "   done (YouTube Android client)"
    return 0
  fi

  echo "   still failing; trying iOS client (NO cookies)..."
  # 3) iOS client, NO cookies (often works when android doesn't)
  local ios=( --extractor-args "youtube:player_client=ios" -o "$outtpl" --no-playlist -S "res,ext:mp4:m4a" )
  [[ -n "${YTDLP_VERBOSE:-}" ]] && echo "yt-dlp ${ios[*]} \"$url\""
  if yt-dlp "${ios[@]}" "$url"; then
    echo "   done (YouTube iOS client)"
    return 0
  fi

  echo "   failed (YouTube)"
  echo "      Tip: list formats with:"
  echo "        yt-dlp --extractor-args \"youtube:player_client=android\" -F \"$url\""
  return 1
}

download_generic_plain_or_cookie_retry() {
  # For X/TikTok: try, then cookie-retry. For others: try once (no cookies).
  local site="$1" url="$2" outtpl="$3" cookie_browser="$4"
  local args=(-o "$outtpl" --no-playlist)

  [[ -n "${YTDLP_VERBOSE:-}" ]] && echo "yt-dlp ${args[*]} \"$url\""
  if yt-dlp "${args[@]}" "$url"; then
    echo "   done"
    return 0
  fi

  if [[ "$site" == "x" || "$site" == "tiktok" ]]; then
    echo "   retrying with browser cookies ($cookie_browser)..."
    local with_cookies=( --cookies-from-browser "$cookie_browser" -o "$outtpl" --no-playlist )
    [[ -n "${YTDLP_VERBOSE:-}" ]] && echo "yt-dlp ${with_cookies[*]} \"$url\""
    yt-dlp "${with_cookies[@]}" "$url" && { echo "   done (with cookies)"; return 0; }
  fi

  echo "   failed"; return 1
}

# url, outname (no ext), folder
download_one() {
  local url="$1"
  local outname="${2:-}"
  local folder="${3:-$DEFAULT_DIR}"

  url="$(printf '%s' "$url" | trim)"
  folder="$(printf '%s' "${folder:-$DEFAULT_DIR}" | trim)"
  [[ -z "$folder" ]] && folder="$DEFAULT_DIR"

  [[ -z "$url" ]] && return 0
  if ! is_url "$url"; then
    echo "Skipping (not a URL): $url" >&2
    return 0
  fi

  local pair site norm
  pair="$(detect_site_and_normalize "$url")"
  site="${pair%%|*}"; norm="${pair##*|}"

  # Output template
  local outtpl
  if [[ -n "$outname" ]]; then
    outname="${outname//\//-}"
    outtpl="${folder}/${outname}.%(ext)s"
  else
    outtpl="${folder}/%(title)s.%(ext)s"
  fi

  if $DRY_RUN; then
    echo "[DRY RUN] Would download [$site] $norm"
    echo "   would save to: $folder"
    [[ -n "$outname" ]] && echo "   filename: $outname.<ext>"
    return 0
  fi

  mkdir -p "$folder"

  echo "-> [$site] $norm"
  echo "   saving to: $folder"

  telegram_helper="${TELEGRAM_HELPER_PATH:-$(dirname "$0")/telegram_dl.py}"
  venv_bin="$HOME/.universal_downloader/venv/bin/python3"

  case "$site" in
    telegram)
      telegram_helper="${TELEGRAM_HELPER_PATH:-$(dirname "$0")/telegram_dl.py}"
      venv_bin="$HOME/.universal_downloader/venv/bin/python3"
      [[ -x "$venv_bin" ]] || { echo "Missing Telegram venv: $venv_bin" >&2; return 1; }

      local bare_name=""
      [[ -n "$outname" ]] && bare_name="$outname"

      echo "   using Telegram helper: $telegram_helper"
      TG_API_ID="${TG_API_ID:?Set TG_API_ID}" TG_API_HASH="${TG_API_HASH:?Set TG_API_HASH}" \
        "$venv_bin" "$telegram_helper" "$norm" "$bare_name" "$folder" \
        && return 0 || return 1
      ;;
  esac

  case "$site" in
    youtube)  download_youtube "$norm" "$outtpl" ;;
    x|tiktok) download_generic_plain_or_cookie_retry "$site" "$norm" "$outtpl" "$BROWSER_DEFAULT" ;;
    rumble|generic)
              download_generic_plain_or_cookie_retry "$site" "$norm" "$outtpl" "$BROWSER_DEFAULT" ;;
    *)        download_generic_plain_or_cookie_retry "$site" "$norm" "$outtpl" "$BROWSER_DEFAULT" ;;
  esac
}

process_txt() {
  local file="$1"
  local ok=0 fail=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(printf '%s' "$line" | trim)"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue

    # Allow "url" OR "url,filename" OR "url,filename,folder"
    IFS=',' read -r col1 col2 col3 <<<"$line"
    local u f dir
    u="$(printf '%s' "$col1" | sed 's/^ *//;s/ *$//')"
    f="$(printf '%s' "$col2" | sed 's/^ *//;s/ *$//')"
    dir="$(printf '%s' "$col3" | sed 's/^ *//;s/ *$//')"
    dir="${dir:-$DEFAULT_DIR}"

    if download_one "$u" "$f" "$dir"; then ok=$((ok+1)); else fail=$((fail+1)); fi
  done < "$file"
  echo "Batch TXT complete: $ok ok, $fail failed."
  [[ $fail -eq 0 ]]
}

process_csv() {
  local file="$1"
  local ok=0 fail=0
  # Simple CSV: url,filename,folder  (header optional)
  while IFS=, read -r col1 col2 col3 || [[ -n "$col1$col2$col3" ]]; do
    # strip optional quotes and spaces
    local u f dir
    u="$(printf '%s' "$col1" | sed 's/^[[:space:]]*"\{0,1\}//; s/"\{0,1\}[[:space:]]*$//' )"
    f="$(printf '%s' "$col2" | sed 's/^[[:space:]]*"\{0,1\}//; s/"\{0,1\}[[:space:]]*$//' )"
    dir="$(printf '%s' "$col3" | sed 's/^[[:space:]]*"\{0,1\}//; s/"\{0,1\}[[:space:]]*$//' )"

    # skip blanks/comments/headers
    [[ -z "$(printf '%s' "$u" | trim)" ]] && continue
    local ulow; ulow="$(printf '%s' "$u" | lower | trim)"
    [[ "$ulow" == "url" ]] && continue
    [[ "$ulow" =~ ^# ]] && continue

    dir="${dir:-$DEFAULT_DIR}"
    if download_one "$u" "$f" "$dir"; then ok=$((ok+1)); else fail=$((fail+1)); fi
  done < "$file"
  echo "Batch CSV complete: $ok ok, $fail failed."
  [[ $fail -eq 0 ]]
}

run_interactive() {
  local url name folder
  read -rp "Paste URL *or* path to .txt/.csv: " url
  url="$(printf '%s' "$url" | trim)"
  if is_file "$url"; then
    local ext="${url##*.}"; ext="$(printf '%s' "$ext" | lower)"
    if [[ "$ext" == "csv" ]]; then
      process_csv "$url"
    else
      process_txt "$url"
    fi
    return
  fi
  read -rp "Optional filename (without extension, blank = use title): " name || true
  printf "Target folder [default: %s]: " "$DEFAULT_DIR"
  read -r folder || true
  folder="$(printf '%s' "${folder:-$DEFAULT_DIR}" | trim)"
  download_one "$url" "$name" "$folder"
}

main() {
  local a1="${1:-}" a2="${2:-}" a3="${3:-$DEFAULT_DIR}"
  if [[ -z "$a1" ]]; then
    run_interactive
  else
    if is_file "$a1"; then
      local ext="${a1##*.}"; ext="$(printf '%s' "$ext" | lower)"
      if [[ "$ext" == "csv" ]]; then
        process_csv "$a1"
      else
        process_txt "$a1"
      fi
    else
      download_one "$a1" "$a2" "$a3"
    fi
  fi
}

main "$@"
