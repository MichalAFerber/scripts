# process_comic_amazing_man
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Processes Amazing-Man Comics files end-to-end: renames them from the raw "Amazing-Man-Comics-5-1939.cbz" format to the standardized "Amazing-Man Comics #005 (1939).cbz" format, detects ZIP files that have been mislabeled with a .cbr extension and converts them to proper .cbz archives, and generates and embeds ComicInfo.xml metadata into each archive.
### How to Use
```bash
# Preview all actions without making changes
bash process_comic_amazing_man.sh --dry-run

# Process files for real
bash process_comic_amazing_man.sh
```
Run from the directory containing the Amazing-Man-Comics files, or adjust the script to `cd` into the target directory. Prerequisites: `zip`, `unzip`, and `file` must be installed. `rar` is required only if you have actual RAR-format .cbr files.
### What and Where to Tweak
- The glob pattern `Amazing-Man-Comics-*` (line 67): Change if your source filenames use a different prefix.
- The regex on line 70: Adjust if your source filename format differs from "Amazing-Man-Comics-<issue>-<year>.<ext>".
- `create_comicinfo()` (line 27): The ComicInfo.xml template. Change the Series, Publisher, or add fields like Summary or LanguageISO.
- `newname` format string (line 78): Modify if you want a different output naming convention.
- `"Centaur Publications"` in the XML template: Change to the correct publisher if adapting for a different series.
