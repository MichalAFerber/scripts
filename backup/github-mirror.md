# github-mirror
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Creates bare mirror clones of all repositories for a GitHub user or organization using the GitHub CLI. Existing mirrors are updated with remote prune; new repos are cloned fresh. After mirroring, the entire local mirror directory is synced to a Wasabi S3 bucket via rclone. Optionally pings Healthchecks.io on completion.
### How to Use
```bash
# Run the mirror and sync
./github-mirror.sh

# Preview what would happen
./github-mirror.sh --dry-run
```
**Prerequisites:**
- `gh` (GitHub CLI) installed and authenticated (`gh auth login`)
- `git` installed
- `jq` installed
- `rclone` installed and configured with a `wasabi-crypt` remote
- SSH key configured for GitHub access
### What and Where to Tweak
- `OWNER` -- GitHub username or organization to mirror (default: `MichalAFerber`)
- `BASE_DIR` -- Local directory for bare mirror clones (default: `/srv/backup/github/$OWNER`)
- `REMOTE` -- rclone remote destination (default: `wasabi-crypt:github/$OWNER`)
- `LOG_FILE` -- Log file path (default: `/var/log/github-mirror.log`)
- `HC_URL` -- Healthchecks.io ping URL for monitoring (optional)
