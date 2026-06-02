# xml-plex
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Parses a Plex library XML export and extracts movie titles and file paths into a date-stamped CSV file. Reads Video nodes from the XML and pulls the title attribute and the file path from each Part node.
### How to Use
Place a `plex.xml` export file in the current directory, then run:
```
python3 xml-plex.py
```
Produces a CSV file named `YYYY-MM-DD_plexmovies.csv` in the current directory.

This is a read-only export -- no files are modified.
### What and Where to Tweak
- `plex.xml` - The input XML filename is hardcoded; change the `ET.parse('plex.xml')` line to point to a different file
- Output filename pattern uses `datetime.now()` for the date prefix
