# rename_movies_for_plex
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Renames movie files in a folder to Plex-friendly "Title (Year).ext" format using IMDb lookups. Strips noise terms (resolution, codec, release group) from filenames, searches IMDb with multiple fallback strategies (partial title, fuzzy matching against top 250), and also renames associated subtitle and image sidecar files. Produces a CSV report and a skipped-files log.
### How to Use
Requires the `cinemagoer` Python package:
```
pip install cinemagoer
```
Dry-run (default, no files renamed):
```
python3 rename_movies_for_plex.py /path/to/movies
```
Apply changes (actually rename files):
```
python3 rename_movies_for_plex.py /path/to/movies -apply
```
Outputs timestamped files in the current directory:
- `YYYY-MM-DD_HH-MM_rename_results.csv` - full results report
- `YYYY-MM-DD_HH-MM_skipped_files.txt` - files that could not be matched
- `YYYY-MM-DD_HH-MM_rename_movies.txt` - debug log
### What and Where to Tweak
- `VIDEO_EXTENSIONS` - tuple of video file extensions to process
- `SUBTITLE_EXTENSIONS` - tuple of subtitle sidecar extensions to rename alongside videos
- `IMAGE_EXTENSIONS` - tuple of image sidecar extensions to rename alongside videos
- `NOISE_TERMS` - regex of release-group and codec terms stripped from filenames before IMDb lookup
- `MAX_THREADS` - number of concurrent IMDb lookup threads (default: 8)
