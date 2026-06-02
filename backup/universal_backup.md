# universal_backup
## Michal Ferber
## Revised Date: 03/27/2026
### Description
A general-purpose backup script that uploads any local directory to a Wasabi S3 bucket via rclone. Supports both copy (additive) and sync (mirror with deletes) modes, optional bandwidth limiting, exclude patterns, and a post-transfer integrity verification pass. Logs all operations with timestamps.
### How to Use
```bash
# Basic copy backup
./universal_backup.sh --src "/data/photos" --dest-sub "immich-raw"

# Sync mode with verification
./universal_backup.sh --src "/data/photos" --dest-sub "immich-raw" --mode sync --verify

# Dry run with excludes
./universal_backup.sh --src "/Volumes/Mando/archives" --excludes ./excludes.txt --dry-run

# With bandwidth limit
./universal_backup.sh --src "/data" --bwlimit 10M
```
**Flags:**
- `--src PATH` -- (required) Source directory
- `--dest-sub SUBPATH` -- Destination subfolder in the bucket (default: `backup-$(hostname)/YYYY-MM-DD`)
- `--mode copy|sync` -- Transfer mode (default: `copy`)
- `--dry-run` -- Preview without making changes
- `--verify` -- Run rclone check after transfer
- `--excludes PATH` -- File with exclude patterns
- `--transfers N` / `--checkers N` -- Concurrency tuning
- `--bwlimit RATE` -- Bandwidth limit (e.g., `10M`)
- `--log-dir PATH` -- Log directory

**Prerequisites:**
- `rclone` installed and configured with a `wasabi-ferber` remote
- Wasabi S3 credentials configured in rclone
### What and Where to Tweak
- `WUB_REMOTE` -- rclone remote name (env var or `.env` file, default: `wasabi-ferber`)
- `WUB_BUCKET` -- S3 bucket name (env var or `.env` file, default: `ferber-storage`)
- `WUB_LOG_DIR` -- Log directory (env var or `.env` file, default: `~/Logs`)
- `WUB_TRANSFERS` -- Concurrent transfers (env var, default: `8`)
- `WUB_CHECKERS` -- Concurrent checkers (env var, default: `16`)
- `WUB_BWLIMIT` -- Bandwidth limit (env var, default: none)
- Place a `.env` file in the working directory to set any of these without exporting
