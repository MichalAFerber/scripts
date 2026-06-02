# plex_wwpv_renamer
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Renames and organizes World's Wildest Police Videos files into Plex-compatible folder structure. Detects season/episode numbers from multiple filename patterns (SxxEyy, 2x05, "Season N, Episode M", etc.), normalizes episode numbering, cleans up titles, and sorts episodes into Season XX folders. Compilations and spin-offs are placed in Season 00 as specials.
### How to Use
Dry-run (default, shows planned moves without executing):
```
python3 plex_wwpv_renamer.py --src "/path/to/source" --dest "/path/to/series/root"
```
Apply changes:
```
python3 plex_wwpv_renamer.py --src "/path/to/source" --dest "/path/to/series/root" --apply
```
Write an audit CSV of all moves:
```
python3 plex_wwpv_renamer.py --src "/path/to/source" --dest "/path/to/dest" --apply --csv ~/rename_log.csv
```
For files that only say "Episode 6" with no season context:
```
python3 plex_wwpv_renamer.py --src "/path/to/source" --dest "/path/to/dest" --assume-season 1
```
### What and Where to Tweak
- `SERIES_NAME` - The series title used in output filenames (default: `World's Wildest Police Videos`)
- `EXTS` - Tuple of video file extensions to process
- `SPECIAL_HINTS` - List of title substrings that trigger placement into Season 00 as specials
