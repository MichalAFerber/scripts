# undo_plex_wwpv_rename
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Reverses file moves/renames made by plex_wwpv_renamer.py using its CSV audit log. Reads the old_path/new_path mapping, determines which direction to move files, and restores them to their original locations. Also moves associated sidecar files (subtitles, artwork, NFO). Appends "(restored N)" to filenames if the original name already exists.
### How to Use
Dry-run (default, shows what would be restored):
```
python3 undo_plex_wwpv_rename.py --csv "/path/to/rename_log.csv"
```
Apply (actually move files back):
```
python3 undo_plex_wwpv_rename.py --csv "/path/to/rename_log.csv" --apply
```
Write an undo log of what was restored:
```
python3 undo_plex_wwpv_rename.py --csv "/path/to/rename_log.csv" --apply --log ~/Desktop/undo_log.csv
```
Ignore rows where neither source nor destination exists:
```
python3 undo_plex_wwpv_rename.py --csv "/path/to/rename_log.csv" --apply --force
```
### What and Where to Tweak
- `--sidecars` - Comma-separated list of sidecar extensions to move alongside video files (default: `.srt,.vtt,.nfo,.jpg,.jpeg,.png`)
