# backup_manager
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Creates intelligent incremental backups with ZIP compression and version management. Only backs up new or modified files by tracking MD5 hashes across runs. Automatically cleans up old backups beyond a configurable retention limit. Supports restoring from any backup version.
### How to Use
```bash
# Preview what files would be backed up (no files written)
python3 backup_manager.py ~/Documents ~/Backups/Documents --dry-run

# Create a backup
python3 backup_manager.py ~/Documents ~/Backups/Documents

# Keep only 5 backup versions
python3 backup_manager.py ~/Documents ~/Backups/Documents --max-backups 5
```
Interactive menu options:
1. Create new backup (incremental, only changed files)
2. List all available backups
3. Restore a backup (to original or alternate location)
4. Show backup statistics
5. Exit

Flags:
- `source_dir` (required, positional): Directory to back up
- `backup_dir` (required, positional): Where to store backup ZIP files and metadata
- `--max-backups N`: Maximum backup versions to retain (default: 10)
- `--dry-run`: Preview what would be backed up or restored without writing any files

Dependencies: Python 3 standard library only (no pip packages).
### What and Where to Tweak
- `max_backups` (CLI flag or constructor param): Controls how many backup ZIPs are kept before old ones are pruned.
- Hash algorithm: Uses MD5 in `_calculate_hash()`. Change to `hashlib.sha256()` if desired.
- Compression: Uses `zipfile.ZIP_DEFLATED`. Change to `zipfile.ZIP_BZIP2` or `zipfile.ZIP_LZMA` for better compression at the cost of speed.
- Metadata is stored as `backup_metadata.json` in the backup directory. This file tracks file hashes and backup history.
