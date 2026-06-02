# sync_movies
## Michal Ferber
## Revised Date: 03/27/2026
### Description
One-way syncs a source movie folder to a Plex media destination using rsync. Shows a dry-run preview of what would change, then asks for confirmation before applying. Uses rsync's `--delete` flag to remove files from the destination that no longer exist in the source. Hidden files (e.g., .DS_Store) are excluded.
### How to Use
Interactive mode (shows preview, prompts before syncing):
```
./sync_movies.sh
```
Dry-run only (no prompt, no changes):
```
./sync_movies.sh --dry-run
```
### What and Where to Tweak
- `SRC` - Source movie folder path (default: `/Volumes/G-DRIVE 12TB/Movies/`)
- `DEST` - Destination Plex library path (default: `/Volumes/G-DRIVE 12TB/PlexMedia/Movies/`)
