# linux-offsite-sync
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Syncs a local snapshot directory to a Wasabi S3 bucket using rclone in mirror mode (sync with delete-after). Designed for offsite backup of Linux server snapshots through an encrypted rclone remote. Optionally pings Healthchecks.io on completion.
### How to Use
```bash
# Run the sync
./linux-offsite-sync.sh

# Preview what would be synced without making changes
./linux-offsite-sync.sh --dry-run
```
**Prerequisites:**
- `rclone` installed and configured with a `wasabi-crypt` remote
- Wasabi S3 credentials configured in rclone
- Write access to the log file location (`/var/log/rclone-offsite.log` by default)
### What and Where to Tweak
- `LOCAL_SNAP_DIR` -- Local directory to sync from (default: `/backup/snapshots`)
- `REMOTE` -- rclone remote destination (default: `wasabi-crypt:linux-snapshots`)
- `LOG_FILE` -- Log file path (default: `/var/log/rclone-offsite.log`)
- `TRANSFERS` -- Number of concurrent file transfers (default: `8`)
- `CHECKERS` -- Number of concurrent checkers (default: `16`)
- `HC_URL` -- Healthchecks.io ping URL for monitoring (optional)
