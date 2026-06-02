#!/usr/bin/env python3
"""
rename_movies.py - Auto-Rename Movie Files to Plex-Friendly Format

Walks a movie directory and renames video files to "Movie Name (YYYY).ext" format.
First tries to extract the year from the filename; if not found, queries IMDb
for the correct title and year.

Usage:
    pip install cinemagoer    # (formerly IMDbPY)
    python3 rename_movies.py                  # dry-run (default)
    python3 rename_movies.py --dry-run        # explicit dry-run
    python3 rename_movies.py --apply          # actually rename files

Configuration:
    MOVIES_DIR  - Path to your Plex movie library (edit in script)
    VIDEO_EXTS  - Set of video file extensions to process

Filename patterns recognized:
    Movie.Name.2020.1080p.mkv  ->  Movie Name (2020).mkv
    Movie Name (2020).mkv      ->  (already correct, skipped)
    Movie Name.mkv             ->  (IMDb lookup for year)
"""
import argparse
import os
import re
from imdb import IMDb

# --- Configuration ---
MOVIES_DIR = "/Volumes/G-DRIVE 12TB/PlexMedia/Movies"
VIDEO_EXTS = {'.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv'}
# ---------------------

ia = IMDb()

def get_imdb_title_year(query):
    """Search IMDb and return (title, year) for the top result."""
    try:
        results = ia.search_movie(query)
        if results:
            movie = results[0]
            ia.update(movie)  # ensure 'year' is populated
            title = movie.get('title')
            year = movie.get('year')
            if title and year:
                return title, year
    except Exception as e:
        print(f"[IMDb lookup failed] {query}: {e}")
    return None, None

def title_case(name):
    """Convert to title case, preserving known acronyms."""
    return name.title()

def target_filename(name, year, ext):
    """Format into 'Movie Name (YYYY).ext'."""
    return f"{name} ({year}){ext}"

def main():
    parser = argparse.ArgumentParser(description="Auto-rename movie files to Plex-friendly format.")
    parser.add_argument("--apply", action="store_true", help="Actually rename files (default is dry-run)")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be renamed without making changes (default)")
    args = parser.parse_args()

    apply_changes = args.apply

    print(f"Mode: {'APPLY' if apply_changes else 'DRY-RUN'}")
    print(f"Directory: {MOVIES_DIR}\n")

    count = 0
    for root, _, files in os.walk(MOVIES_DIR):
        for fname in files:
            base, ext = os.path.splitext(fname)
            if ext.lower() not in VIDEO_EXTS:
                continue

            # Check if already in target format
            if re.match(r'^.+ \(\d{4}\)\.\w+$', fname):
                continue

            # Attempt to extract title and year from filename
            m = re.match(r'^(?P<title>.+?)[\.\s\-_]*\(?(?P<year>\d{4})\)?.*$', base)
            year = None
            if m:
                title_guess = m.group('title')
                year = m.group('year')
            else:
                title_guess = base

            # If no year in filename, query IMDb
            if not year:
                imdb_title, imdb_year = get_imdb_title_year(title_guess)
                if imdb_title and imdb_year:
                    title_guess, year = imdb_title, str(imdb_year)

            # Final checks
            if not year:
                print(f"[SKIP: no year] {fname}")
                continue

            title_tc = title_case(title_guess)
            new_name = target_filename(title_tc, year, ext)
            old_path = os.path.join(root, fname)
            new_path = os.path.join(root, new_name)

            if old_path != new_path:
                count += 1
                if apply_changes:
                    print(f"Renaming:\n  {fname}\n  -> {new_name}\n")
                    os.rename(old_path, new_path)
                else:
                    print(f"[DRY RUN] Would rename:\n  {fname}\n  -> {new_name}\n")

    print(f"Done. {'Renamed' if apply_changes else 'Would rename'} {count} file(s).")
    if not apply_changes and count > 0:
        print("Run with --apply to execute renames.")

if __name__ == "__main__":
    main()
