# sync_to_wasabi
## Michal Ferber
## Revised Date: 03/27/2026
### Description
An interactive rsync script that syncs a Blackbox external drive (Red or Blue) to Wasabi S3 cloud storage via a MountainDuck-mounted filesystem. Prompts the user to select the source drive, choose dry-run or live mode, and confirm before proceeding. Logs all output with timestamps. Uses additive sync only (no `--delete` flag), so files in the cloud are never removed.
### How to Use
```bash
# Run interactively -- the script will prompt for all choices
./sync_to_wasabi.sh
```
The script will ask:
1. Which Blackbox drive to sync from (Red or Blue)
2. Whether to perform a dry-run first (recommended)
3. Whether to show a progress bar
4. Final confirmation before proceeding

**Prerequisites:**
- `rsync` installed at `/opt/homebrew/bin/rsync` (Homebrew version)
- MountainDuck running with Wasabi S3 mounted at the configured path
- Blackbox E Red or Blue external drive connected
### What and Where to Tweak
- `RED_DRIVE` -- Mount path for Blackbox E Red (default: `/Volumes/Blackbox E Red`)
- `BLUE_DRIVE` -- Mount path for Blackbox E Blue (default: `/Volumes/Blackbox E Blue`)
- `WASABI_PATH` -- MountainDuck mount point for Wasabi (default: `/Users/michal/Library/CloudStorage/MountainDuck-s3.us-east-1.wasabisys.com-S3/ferber-storage`)
- `LOG_DIR` -- Log directory (default: `~/Documents/Logs`)
- Excluded patterns: `.fseventsd`, `.Spotlight-V100`, `.Trashes`, `.TemporaryItems`, `.DS_Store` (edit the rsync `--exclude` flags to change)
- The rsync binary path is hardcoded to `/opt/homebrew/bin/rsync` -- change if your rsync is elsewhere
