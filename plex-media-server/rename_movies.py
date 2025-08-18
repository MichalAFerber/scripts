#!/usr/bin/env python3
import os
import re
import sys
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
    for root, _, files in os.walk(MOVIES_DIR):
        for fname in files:
            base, ext = os.path.splitext(fname)
            if ext.lower() not in VIDEO_EXTS:
                continue

            # Check if already in target format
            if re.match(r'^.+ \(\d{4}\)\.\w+$', fname):
                continue

            # Attempt to extract title and year from filename
            m = re.match(r'^(?P<title>.+?)[\.\s\-_]*\(?P<year>\d{4}\)?.*$', base)
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
                print(f"Renaming:\n  {fname}\n→ {new_name}\n")
                os.rename(old_path, new_path)  # uses os.rename :contentReference[oaicite:4]{index=4}

if __name__ == "__main__":
    main()
