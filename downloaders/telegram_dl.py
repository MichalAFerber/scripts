#!/usr/bin/env python3
"""
telegram_dl.py — Download a single Telegram message's media.

Usage:
  TG_API_ID=123 TG_API_HASH=abc... \
  python3 telegram_dl.py <t.me URL> [outname-without-ext] [folder]

  TG_API_ID=123 TG_API_HASH=abc... \
  python3 telegram_dl.py --dry-run <t.me URL> [outname-without-ext] [folder]

Supported links:
  https://t.me/<username>/<msg_id>
  https://t.me/c/<internal_chat_id>/<msg_id>     # private groups/channels
  https://t.me/s/<username>/<msg_id>             # public 's' mirror links

Notes:
  - First run: prompts for phone + code (creates session file).
  - You must have access to the chat for private (/c) links.
"""

import os, sys, pathlib, urllib.parse
from telethon import TelegramClient
from telethon.errors import MessageIdInvalidError

def err(msg): print(msg, file=sys.stderr); sys.exit(1)

# --- parse --dry-run ---
dry_run = False
argv = sys.argv[1:]
if "--dry-run" in argv:
    dry_run = True
    argv.remove("--dry-run")

# --- creds ---
if "TG_API_ID" not in os.environ or "TG_API_HASH" not in os.environ:
    err("Missing TG_API_ID / TG_API_HASH env vars.")
api_id  = int(os.environ["TG_API_ID"])
api_hash= os.environ["TG_API_HASH"]

# --- args ---
if len(argv) < 1:
    err("Usage: TG_API_ID=... TG_API_HASH=... python3 telegram_dl.py [--dry-run] <t.me URL> [outname] [folder]")

url     = argv[0]
outname = argv[1] if len(argv) >= 2 else ""
folder  = argv[2] if len(argv) >= 3 else os.path.join(os.path.expanduser("~"), "Downloads")

folder_path = pathlib.Path(folder).expanduser().resolve()

# Session file dir (configurable)
sess_dir = pathlib.Path(os.environ.get("TG_SESSION_DIR", os.path.join(os.path.expanduser("~"), ".universal_downloader")))
sess_dir.mkdir(parents=True, exist_ok=True)
session_path = str(sess_dir / "telegram")

# --- parse t.me URL robustly ---
p = urllib.parse.urlparse(url)
if p.netloc not in {"t.me", "www.t.me"}:
    err("Not a t.me link.")

parts = [seg for seg in p.path.split("/") if seg]  # e.g. ['c','1234567','89'] or ['user','123']
if len(parts) < 2:
    err("Unsupported Telegram URL. Expect /<user>/<msg> or /c/<internal>/<msg>.")

entity = None
try:
    if parts[0] == "c":
        # /c/<internal_chat_id>/<msg_id>
        if len(parts) < 3:
            err("Invalid /c link. Expect /c/<internal_chat_id>/<msg_id>.")
        internal_id = int(parts[1])
        entity = int(f"-100{internal_id}")  # supergroup/channel peer id
        msg_id = int(parts[2])
    elif parts[0] == "s":
        # /s/<username>/<msg_id> (public mirror)
        if len(parts) < 3:
            err("Invalid /s link. Expect /s/<username>/<msg_id>.")
        entity = parts[1]
        msg_id = int(parts[2])
    else:
        # /<username>/<msg_id>
        entity = parts[0]
        msg_id = int(parts[1])
except ValueError:
    err("Message ID (or internal chat id) is not numeric.")

if dry_run:
    print(f"[DRY RUN] Would download message {msg_id} from {entity}")
    print(f"   would save to: {folder_path}")
    if outname.strip():
        print(f"   filename: {outname}")
    sys.exit(0)

folder_path.mkdir(parents=True, exist_ok=True)

async def run():
    async with TelegramClient(session_path, api_id, api_hash) as client:
        try:
            msg = await client.get_messages(entity, ids=msg_id)
        except MessageIdInvalidError:
            err("Message not found or you don't have access.")
        except Exception as e:
            err(f"Failed to fetch message: {e}")

        if not msg or not (msg.video or msg.document or msg.photo or msg.audio or msg.voice):
            err("No downloadable media found in that message.")

        # filename: prefer user-provided; else Telegram's; else fallback
        base = (outname.strip()
                or (msg.file and msg.file.name)
                or f"telegram_{msg_id}")
        target = folder_path / base

        out = await msg.download_media(file=str(target))
        print(out or str(target))

if __name__ == "__main__":
    import asyncio
    asyncio.run(run())
