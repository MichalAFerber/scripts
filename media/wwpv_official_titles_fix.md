# wwpv_official_titles_fix
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Applies a series of targeted fixes to the World's Wildest Police Videos library structure: moves any misplaced "Season 06" contents into Season 00 (specials), relocates 6 Season 1 episodes from Season 00 into Season 01 with correct numbering and titles, fixes the S03E05 title to "High-Speed Chases", and retitles all Season 05 episodes to their official names.
### How to Use
Dry-run (default, shows what would be changed):
```
python3 wwpv_official_titles_fix.py /path/to/series/root
python3 wwpv_official_titles_fix.py /path/to/series/root --dry-run
```
Apply changes:
```
python3 wwpv_official_titles_fix.py /path/to/series/root --apply
```
If no path is given, uses the current directory.
### What and Where to Tweak
- `series` - The series name used in output filenames (default: `World's Wildest Police Videos`)
- `s01_titles` / `s01_matchers` - List of Season 1 episode titles and their filename-matching regex patterns
- `s05_titles` - Dictionary mapping Season 5 episode numbers to their official titles
