# generate_comicinfo
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Generates ComicInfo.xml metadata files for Amazing-Man Comics CBZ/CBR archives. For CBZ files, the XML is created and then embedded directly into the archive. For CBR files, the XML is left as a separate file alongside the archive since CBR (RAR) archives cannot be safely modified in place.
### How to Use
```bash
# Preview what would be created/embedded
cd ~/Desktop/Amazing-Man-Comics && bash generate_comicinfo.sh --dry-run

# Generate and embed metadata for real
cd ~/Desktop/Amazing-Man-Comics && bash generate_comicinfo.sh
```
Prerequisites: `zip` must be installed (used to embed XML into CBZ archives). Files must follow the naming pattern "Amazing-Man Comics #005 (1939).cbz".
### What and Where to Tweak
- `COMIC_DIR` (line 28): Path to the directory containing your comic files. Defaults to `$HOME/Desktop/Amazing-Man-Comics`.
- `series` (line 40): The series name is hardcoded to "Amazing-Man Comics". Change this for a different comic series.
- The ComicInfo.xml template (lines 61-71): Add or modify XML fields such as Publisher, Summary, or LanguageISO to suit your metadata requirements.
- `"Centaur Publishing"` in the XML template: Change to the correct publisher if processing a different series.
