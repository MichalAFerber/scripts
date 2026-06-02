# download_x
## Michal Ferber
## Revised Date: 03/27/2026
### Description
A simpler single-URL downloader for YouTube, Rumble, TikTok, and X (Twitter) videos. Uses yt-dlp and automatically retries with browser cookies for X and TikTok when a plain download fails. Normalizes X/Twitter URLs to their canonical form.
### How to Use
With arguments:
```
./download_x.sh "https://x.com/user/status/1910110429533077904" "myfile"
```
Interactive mode (prompts for URL and filename):
```
./download_x.sh
```
Preview what would be downloaded:
```
./download_x.sh --dry-run "https://x.com/user/status/123"
```
Prerequisites: `yt-dlp` must be installed and on PATH.
### What and Where to Tweak
- `YTDLP_BROWSER` -- which browser to pull cookies from when retrying (default: chrome). Options: chrome, firefox, brave, edge, chromium.
- The script saves to the current working directory. `cd` to your desired folder before running, or modify the `-o` output template in the `ARGS` array.
