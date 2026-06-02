# telegram_dl
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Downloads media (video, photo, audio, document) from a single Telegram message given its t.me URL. Uses the Telethon library to connect to the Telegram API. Supports public channels, private groups/channels (if you have access), and public mirror (/s/) links.
### How to Use
```
TG_API_ID=123456 TG_API_HASH=abcdef... \
  python3 telegram_dl.py "https://t.me/channel/123" "my-video" ~/Downloads
```
Arguments:
1. `<t.me URL>` -- the Telegram message link (required)
2. `[outname]` -- filename without extension (optional; defaults to Telegram's filename or `telegram_<msg_id>`)
3. `[folder]` -- destination folder (optional; defaults to `~/Downloads`)

Preview what would be downloaded:
```
TG_API_ID=123456 TG_API_HASH=abcdef... \
  python3 telegram_dl.py --dry-run "https://t.me/channel/123"
```
On first run, Telethon will prompt for your phone number and a login code to create a session file.

Prerequisites:
- Python 3 with `telethon` installed (typically in a venv at `~/.universal_downloader/venv/`).
- Telegram API credentials: `TG_API_ID` and `TG_API_HASH` environment variables (obtain from https://my.telegram.org).
### What and Where to Tweak
- `TG_API_ID` / `TG_API_HASH` -- your Telegram API credentials, set as environment variables.
- `TG_SESSION_DIR` -- directory for the Telethon session file (default: `~/.universal_downloader`).
- The default download folder is `~/Downloads`; pass a third argument or modify the `folder` default in the script.
