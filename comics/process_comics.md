# process_comics
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Batch processes comic book archives (CBZ/CBR) in the current directory and subdirectories. It normalizes filenames to a standard "Series #001 (YYYY).ext" format, detects ZIP files that have been mislabeled as .cbr and converts them to .cbz, and generates and embeds ComicInfo.xml metadata into CBZ archives. All actions are logged to a timestamped file.
### How to Use
```bash
# Preview changes without modifying anything
cd /path/to/comics && bash process_comics.sh --dry-run

# Run for real - rename, convert, and embed metadata
cd /path/to/comics && bash process_comics.sh

# Re-embed ComicInfo.xml into files that are already formatted
cd /path/to/comics && bash process_comics.sh --regen
```
Prerequisites: `zip` and `unzip` must be installed.
### What and Where to Tweak
- `LOG_DIR` (line 21): Directory where log files are written. Defaults to `logs/` in the current directory.
- `EXPECTED_REGEX` (line 44): The regex that defines a "correctly formatted" filename. Adjust if your naming convention differs from "Series #001 (YYYY).ext".
- `generate_comicinfo()` (line 46): The ComicInfo.xml template. Add or change XML fields (Publisher, Summary, etc.) to match your metadata needs.
- `normalize_name()` (line 71): The logic that parses raw filenames into the standard format. Adjust the series/issue/year extraction if your source filenames use a different pattern.
