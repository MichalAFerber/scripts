# universal_backup.ps1
## Michal Ferber
## Revised Date: 03/27/2026
### Description
PowerShell version of the universal Wasabi backup script. Uploads any local directory to a Wasabi S3 bucket via rclone with support for copy or sync modes, bandwidth limiting, exclude patterns, and post-transfer verification. Loads configuration from environment variables or a `.env` file.
### How to Use
```powershell
# Basic copy backup
.\universal_backup.ps1 -Src "C:\Data\Photos" -DestSub "immich-raw"

# Sync mode with verification
.\universal_backup.ps1 -Src "C:\Data\Photos" -DestSub "immich-raw" -Mode sync -Verify

# Dry run
.\universal_backup.ps1 -Src "D:\Archives" -DryRun

# With bandwidth limit and excludes
.\universal_backup.ps1 -Src "C:\Data" -Bwlimit "10M" -Excludes ".\excludes.txt"
```
**Parameters:**
- `-Src` -- (required, prompted if missing) Source directory
- `-DestSub` -- Destination subfolder in the bucket (default: `backup-$COMPUTERNAME/YYYY-MM-DD`)
- `-Mode copy|sync` -- Transfer mode (default: `copy`)
- `-DryRun` -- Preview without making changes
- `-Verify` -- Run rclone check after transfer
- `-Excludes` -- File with exclude patterns
- `-Transfers` / `-Checkers` -- Concurrency tuning (defaults: 8/16)
- `-Bwlimit` -- Bandwidth limit
- `-LogDir` -- Log directory (default: `~/Logs`)

**Prerequisites:**
- `rclone` installed and configured with a `wasabi-ferber` remote
- Wasabi S3 credentials configured in rclone
- PowerShell 5.1+ or PowerShell 7+
### What and Where to Tweak
- `WUB_REMOTE` -- rclone remote name (env var or `.env` file, default: `wasabi-ferber`)
- `WUB_BUCKET` -- S3 bucket name (env var or `.env` file, default: `ferber-storage`)
- Place a `.env` file in the working directory to override defaults without setting env vars
- Adjust `-Transfers` and `-Checkers` for your network speed
