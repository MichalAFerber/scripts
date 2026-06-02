# rename_movies
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Walks a movie directory and renames video files into Plex-friendly "Movie Name (YYYY).ext" format. Extracts the year from the filename when possible; otherwise queries IMDb for the correct title and year. Files already in the correct format are skipped.
### How to Use
Requires the `cinemagoer` Python package (formerly IMDbPY):
```
pip install cinemagoer
```
Dry-run (default, shows what would be renamed):
```
python3 rename_movies.py
python3 rename_movies.py --dry-run
```
Apply changes (actually rename files):
```
python3 rename_movies.py --apply
```
### What and Where to Tweak
- `MOVIES_DIR` - Path to your Plex movie library (default: `/Volumes/G-DRIVE 12TB/PlexMedia/Movies`)
- `VIDEO_EXTS` - Set of video file extensions to process (default: `.mp4`, `.mkv`, `.avi`, `.mov`, `.wmv`, `.flv`)
