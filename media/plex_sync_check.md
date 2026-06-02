# plex_sync_check
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Compares a source movie folder to a Plex destination folder by relative path. Supports three modes: check (report missing files), copy (copy missing files to destination), and verify (SHA-256 checksum comparison of files present in both locations). Produces a CSV report of all findings.
### How to Use
Check for missing files (default):
```
./plex_sync_check.sh
./plex_sync_check.sh --src /path/to/source --dst /path/to/dest --check
```
Copy missing files to destination:
```
./plex_sync_check.sh --copy
./plex_sync_check.sh --copy --dry-run   # preview what would be copied
```
Verify checksums of existing files:
```
./plex_sync_check.sh --verify
```
Additional options:
```
--report <file>     Write CSV report to a specific file
--exclude <glob>    Exclude files matching a glob pattern (repeatable)
--quiet             Suppress progress output
```
This is a read-only check in `--check` and `--verify` modes. The `--copy` mode writes files; use `--dry-run` with it to preview.
### What and Where to Tweak
- `SRC_DIR` - Source movie folder (default: `/Volumes/G-DRIVE 12TB/Movies`)
- `DST_DIR` - Destination Plex library folder (default: `/Volumes/G-DRIVE 12TB/PlexMedia/Movies`)
- `DEFAULT_EXCLUDES` - Array of filenames always excluded (default: `.DS_Store`, `Thumbs.db`, `@eaDir`)
