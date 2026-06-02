# xml-plex-compare
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Compares a Plex library XML export against the actual files on disk. Cross-references movies listed in the XML with files in a media directory, producing a CSV report showing which titles exist in the XML, which files exist on disk, and any mismatches in either direction.
### How to Use
Place a `plex.xml` export file in the current directory, then run:
```
python3 xml-plex-compare.py
```
Produces a CSV file named `YYYY-MM-DD_plexmovies.csv` with columns: Title, File, Exists in Directory, Exists in XML.

This is a read-only comparison -- no files are modified.
### What and Where to Tweak
- `directory` - Path to the on-disk media directory to compare against (default: `/mnt/plexmedia`)
- `plex.xml` - The input XML filename is hardcoded in the `ET.parse()` call
- `"/Volumes/G-Drive/PlexMedia/Movies/"` - The path prefix stripped from XML file paths for comparison; adjust to match your Plex library's base path
