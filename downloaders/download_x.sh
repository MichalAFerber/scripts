#!/usr/bin/env bash
# download_x.sh — universal downloader (YouTube, Rumble, TikTok, X)
# Usage:
#   ./download_x.sh
#     → prompts for URL and filename
#   ./download_x.sh "https://x.com/user/status/1910110429533077904" "myfile"
#     → saves as ./myfile.<ext>
#
# Env:
#   YTDLP_BROWSER=chrome|firefox|brave|edge|chromium  (default: chrome)

set -euo pipefail

BROWSER="${YTDLP_BROWSER:-chrome}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need yt-dlp

URL="${1:-}"
OUTNAME="${2:-}"

# Interactive prompts if missing
if [[ -z "${URL}" ]]; then
  read -rp "Paste video URL (YouTube/Rumble/TikTok/X): " URL
fi
if [[ -z "${OUTNAME}" ]]; then
  read -rp "Optional filename (without extension, blank = use title): " OUTNAME || true
  OUTNAME="${OUTNAME:-}"
fi

trim() { awk '{$1=$1;print}'; }
URL="$(printf '%s' "$URL" | trim)"

if [[ -z "$URL" ]]; then
  echo "No URL provided." >&2
  exit 2
fi

# Determine site + normalize if needed
site=""
norm_url="$URL"

is_x_id() { [[ "$1" =~ ([0-9]{10,}) ]] && echo "${BASH_REMATCH[1]}" || return 1; }

case "$URL" in
  *youtube.com*|*youtu.be*)
    site="youtube"
    ;;
  *rumble.com*)
    site="rumble"
    ;;
  *tiktok.com*)
    site="tiktok"
    ;;
  *twitter.com*|*x.com*)
    site="x"
    # Normalize any X/Twitter URL to canonical /i/web/status/ID
    if id="$(is_x_id "$URL")"; then
      norm_url="https://x.com/i/web/status/${id}"
    fi
    ;;
  *)
    # Fallback: let yt-dlp try anyway
    site="generic"
    ;;
esac

# Build output template
if [[ -n "${OUTNAME}" ]]; then
  # sanitize slashes
  OUTNAME="${OUTNAME//\//-}"
  OUTTPL="${OUTNAME}.%(ext)s"
else
  OUTTPL="%(title)s.%(ext)s"
fi

# Base args: write to current folder
ARGS=(-o "$OUTTPL" --no-playlist)

# Site-specific tweaks
case "$site" in
  youtube)
    # Nothing special; yt-dlp does great by default
    ;;
  rumble)
    # Rumble can be slow to probe; keep defaults
    ;;
  tiktok)
    # Often needs cookies for age/region. We'll try no cookies first, then retry with browser.
    ;;
  x)
    # X frequently needs cookies; we’ll attempt plain then cookie-backed.
    ;;
  generic)
    ;;
esac

echo "→ Detected site: $site"
echo "→ Saving as template: $OUTTPL"
echo "→ URL: $norm_url"
echo

# Try download; for X/TikTok add cookie retry
try_plain() {
  yt-dlp "${ARGS[@]}" "$norm_url"
}

try_with_cookies() {
  echo "Retrying with browser cookies (${BROWSER})…"
  yt-dlp --cookies-from-browser "$BROWSER" "${ARGS[@]}" "$norm_url"
}

success=0
if [[ "$site" == "x" || "$site" == "tiktok" ]]; then
  if try_plain; then
    success=1
  else
    if try_with_cookies; then
      success=1
    fi
  fi
else
  if try_plain; then
    success=1
  fi
fi

if [[ "$success" -eq 1 ]]; then
  echo "✅ Done."
else
  echo "❌ Download failed."
  echo "Tips:"
  echo "  • Make sure you can view the video in your browser (age/protection/region)."
  echo "  • Set YTDLP_BROWSER=firefox (or chrome/brave/edge/chromium) and retry."
  echo "  • For X quoted posts: open the quoted post and use its link."
  exit 3
fi

