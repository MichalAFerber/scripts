# sync_archives
## Michal Ferber
## Revised Date: 03/27/2026
### Description
An interactive script that mirrors the contents of one external Blackbox drive to the other using rsync. It prompts the user to choose the source drive (Red or Blue), offers a dry-run option, and performs a one-way sync with `--delete` to make the destination an exact copy of the source. Excludes macOS system files and logs all output to a timestamped log file.
### How to Use
```bash
# Run interactively (will prompt for source, dry-run, and confirmation)
./sync_archives.sh

# Skip the dry-run prompt by passing it as a flag
./sync_archives.sh --dry-run

# Disable the progress bar
./sync_archives.sh --no-progress

# Combine flags
./sync_archives.sh --dry-run --no-progress
```
Prerequisites: Both external drives must be mounted at `/Volumes/Blackbox E Red` and `/Volumes/Blackbox E Blue`. rsync must be installed.
### What and Where to Tweak
- `LOG_DIR` (line 4): Directory where sync logs are saved (default: `$HOME/Documents/Logs`).
- Drive names/paths (lines 41-44): Change `SOURCE` and `DEST` paths if your drives have different names.
- Exclude patterns (lines 111-115): Add or remove macOS system files to skip during sync.
- rsync flags (line 110): Adjust `--no-perms --no-owner --no-group` if your drives support Unix permissions.
