# rclone-wasabi-ferber-storage
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Uploads a local directory to a Wasabi S3 bucket (`ferber-storage`) using rclone. Supports both copy (additive, never deletes) and sync (mirror, deletes extras at destination) modes. Optionally runs a post-transfer integrity check using `rclone check`. Logs warnings and errors to a timestamped file.
### How to Use
```bash
# Copy a folder to Wasabi (default date-based prefix)
./rclone-wasabi-ferber-storage.sh "/Volumes/Mando"

# Copy with a custom destination prefix
./rclone-wasabi-ferber-storage.sh "/Volumes/Mando" "backup-mando/2025-08-15"

# Dry run to preview
./rclone-wasabi-ferber-storage.sh "/Volumes/Mando" --dry-run

# Sync mode with verification
./rclone-wasabi-ferber-storage.sh "/Volumes/Mando" --sync --verify

# Adjust upload concurrency
./rclone-wasabi-ferber-storage.sh "/data" "backups" --upload-concurrency=8
```
**Flags:**
- `--dry-run` -- Preview without making changes
- `--verify` -- Run integrity check after transfer
- `--sync` -- Mirror mode (deletes extras at destination)
- `--upload-concurrency=N` -- Parallel parts per large upload (default: 4)

**Prerequisites:**
- `rclone` installed (`brew install rclone`)
- rclone configured with a `wasabi-ferber` remote pointing to Wasabi S3
### What and Where to Tweak
- `SRC_DEFAULT` -- Default source directory (default: `$HOME/Downloads`)
- `DEST_PREFIX_DEFAULT` -- Default destination prefix (default: `backups/YYYY-MM-DD`)
- `WASABI_REMOTE` -- rclone remote name (hardcoded: `wasabi-ferber`)
- `DEST_BUCKET` -- S3 bucket name (hardcoded: `ferber-storage`)
- `UPLOAD_CONCURRENCY` -- Parallel parts per upload (default: `4`)
- `LOG_DIR` -- Log directory (default: `~/Logs`)
- Excluded patterns: `.DS_Store`, `._*`, `.Spotlight-*`, `.Trashes` (edit the `RC_FLAGS` array to change)
