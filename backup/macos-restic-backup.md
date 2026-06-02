# macos-restic-backup
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Runs a nightly encrypted backup of macOS user directories to a Wasabi S3 bucket using Restic with rclone as the backend. It creates incremental snapshots, prunes old snapshots based on a configurable retention policy, and performs a post-backup integrity check. Optionally pings a Healthchecks.io URL on success.
### How to Use
```bash
# Standard backup
./macos-restic-backup.sh

# Preview what would happen without making changes
./macos-restic-backup.sh --dry-run
```
**Prerequisites:**
- `restic` installed (`brew install restic`)
- `rclone` installed and configured with a `wasabi-crypt` remote
- Restic password stored in macOS Keychain under `restic-pass`, or set `RESTIC_PASSWORD` env var
- An excludes file at `~/.config/restic/excludes.txt` (auto-copied from examples on first run)
### What and Where to Tweak
- `RESTIC_REPO` -- Restic repository path (default: `rclone:wasabi-crypt:macos-restic`)
- `RESTIC_PASSWORD_COMMAND` -- Command to retrieve the restic password (default: macOS Keychain lookup)
- `BACKUP_PATHS` -- Array of directories to back up (default: `/Users/$USER`)
- `EXCLUDES_FILE` -- Path to the restic excludes file (default: `~/.config/restic/excludes.txt`)
- `LOG_DIR` -- Where logs are written (default: `~/Logs`)
- `RETENTION_ARGS` -- Restic forget retention policy (default: 7 daily, 5 weekly, 12 monthly, 7 yearly)
- `HC_URL` -- Healthchecks.io ping URL for monitoring (optional)
