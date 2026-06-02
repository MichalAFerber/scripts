# apply_official_titles_wwpv
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Applies official episode titles to World's Wildest Police Videos Season 05 files. Matches existing files by their S05Exx pattern and renames them to include the correct episode title. Safe to run multiple times -- already-correct files are skipped, and existing targets are not overwritten.
### How to Use
Dry-run (default, shows planned renames):
```
python3 apply_official_titles_wwpv.py --root "/path/to/wwpv"
```
Apply changes:
```
python3 apply_official_titles_wwpv.py --root "/path/to/wwpv" --apply
```
The `--root` path should be the series root that contains a `Season 05` subfolder.
### What and Where to Tweak
- `SERIES` - The series name used in filenames (default: `World's Wildest Police Videos`)
- `S5_TITLES` - Dictionary mapping episode numbers (1-13) to their official titles. Add or change entries to adjust which episodes get renamed.
