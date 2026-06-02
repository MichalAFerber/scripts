# rename_comic_amazing_man
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Renames Amazing-Man Comics files from a hyphenated format ("Amazing-Man-Comics-5-1939.cbz") to a standardized, human-readable format with zero-padded issue numbers ("Amazing-Man Comics #005 (1939).cbz"). Files that already match the target format are skipped.
### How to Use
```bash
# Preview renames without changing anything
bash rename_comic_amazing_man.sh --dry-run

# Rename files for real
bash rename_comic_amazing_man.sh
```
No external dependencies beyond standard shell utilities.
### What and Where to Tweak
- `COMIC_DIR` (line 26): Path to the directory containing your comic files. Defaults to `$HOME/Desktop/Amazing-Man-Comics`.
- The glob pattern `Amazing-Man-Comics-*` (line 29): Change if your source filenames use a different prefix.
- The `sed` patterns for `issue` and `year` extraction (lines 35-36): Adjust if your source filename format differs from "Amazing-Man-Comics-<issue>-<year>.<ext>".
- `newname` format string (line 41): Modify if you want a different output naming convention (e.g., different padding width or separator).
