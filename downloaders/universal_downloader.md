# universal_downloader
## Michal Ferber
## Revised Date: 03/27/2026
### Description
A multi-site media downloader supporting YouTube, Rumble, TikTok, X (Twitter), and Telegram. Accepts a single URL, interactive prompts, or batch input via .txt or .csv files. Uses yt-dlp under the hood, with automatic cookie-based retries for sites that require authentication. Telegram downloads are handled via a companion Python helper (telegram_dl.py).
### How to Use
Single URL:
```
./universal_downloader.sh "https://youtube.com/watch?v=..." "my-video" ~/Videos
```
Batch from a text file (one URL per line, optionally with filename and folder separated by commas):
```
./universal_downloader.sh list.txt
```
Batch from a CSV (columns: url, filename, folder):
```
./universal_downloader.sh list.csv
```
Interactive mode (no arguments):
```
./universal_downloader.sh
```
Preview what would be downloaded without actually downloading:
```
./universal_downloader.sh --dry-run "https://x.com/user/status/123"
./universal_downloader.sh --dry-run list.txt
```
Prerequisites:
- `yt-dlp` must be installed and on PATH.
- For Telegram downloads: a Python venv at `~/.universal_downloader/venv/` with telethon installed, plus `TG_API_ID` and `TG_API_HASH` environment variables set.
### What and Where to Tweak
- `YTDLP_BROWSER` -- browser for cookie extraction on non-YouTube sites (default: chrome). Set to firefox, brave, edge, or chromium as needed.
- `YTDLP_YT_BROWSER` -- browser for YouTube cookie extraction (default: safari).
- `YTDLP_DEFAULT_DIR` -- default save folder (default: `$HOME/Downloads`).
- `YTDLP_VERBOSE=1` -- set to echo the exact yt-dlp commands being run.
- `TELEGRAM_HELPER_PATH` -- override the path to telegram_dl.py if it is not in the same directory.
- `TG_SESSION_DIR` -- where Telegram session files are stored (default: `~/.universal_downloader`).
