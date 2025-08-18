#!/usr/bin/env python3
import os
import re
import sys
import csv
import logging
from datetime import datetime
from imdb import IMDb
from concurrent.futures import ThreadPoolExecutor, as_completed
from difflib import get_close_matches

# Configuration
VIDEO_EXTENSIONS = (".mp4", ".mkv", ".avi", ".mov")
SUBTITLE_EXTENSIONS = (".srt", ".sub", ".idx")
IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")
NOISE_TERMS = re.compile(r'\b(?:MKV|480p|720p|1080p|2160p|4k|WEBRip|WEB-DL|BluRay|HDRip|DVDRip|x264|x265|H\.264|H\.265|HEVC|AAC|MP3|DD5\.1|HDR|DUAL|YIFY|RARBG|10Bit|gdtr|xvid|YTS|MX|BRRip|DVDR|CAM|TS|HC|ES|ENG|SPA|FRE|OFT|AM|Ronbo|ETRG|EVO|FGT|GalaxyRG|Subs|UNCUT|REMASTERED|IMAX|HDR10|NF|WEB|HD|SD)\b', re.IGNORECASE)

TIMESTAMP = datetime.now().strftime("%Y-%m-%d_%H-%M")
SKIPPED_LOG_FILE = f"{TIMESTAMP}_skipped_files.txt"
LOG_FILE = f"{TIMESTAMP}_rename_movies.txt"
CSV_REPORT_FILE = f"{TIMESTAMP}_rename_results.csv"
MAX_THREADS = 8

# IMDb API
ia = IMDb()

# Logging setup
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.DEBUG,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
console = logging.StreamHandler()
console.setLevel(logging.ERROR)
console.setFormatter(logging.Formatter('%(message)s'))
logging.getLogger('').addHandler(console)
logging.getLogger('imdb').setLevel(logging.WARNING)

results = []
skipped = []

def correct_grammar(name):
    corrections = {
        r'\bMillers\b': "Miller's",
        r'\bDont\b': "Don't",
        r'\bIts\b': "It's",
        r'\bIm\b': "I'm"
    }
    for pattern, replacement in corrections.items():
        name = re.sub(pattern, replacement, name)
    return name

def extract_title_year(filename):
    name, ext = os.path.splitext(filename)
    name = re.sub(r'(?<!^)\.(?!\w+$)', ' ', name)
    name = re.sub(r'[\[\](){}]', '', name)
    name = NOISE_TERMS.sub('', name)
    name = re.sub(r'\s+', ' ', name).strip()
    match = re.search(r'(?P<title>.+?)\s+(?P<year>19\d{2}|20\d{2})\b', name)
    if match:
        title = match.group('title')
        title = re.sub(r'\s*[^\w\s]+$', '', title)
        title = re.sub(r'\b\d+\b', '', title)
        title = re.sub(r'[^\w\s]', '', title).strip()
        title = correct_grammar(title)
        return title.strip(), int(match.group('year'))
    return name.strip(), None

def find_imdb_title(title, year=None):
    try:
        search_attempts = []
        cleaned_title = title
        results = ia.search_movie(title)
        search_attempts.append(f"Initial: '{title}'")

        if not results and year:
            title_no_year = re.sub(r'\b(19\d{2}|20\d{2})\b', '', title).strip()
            results = ia.search_movie(title_no_year)
            search_attempts.append(f"Retry w/o year: '{title_no_year}'")

        if not results:
            short_title = ' '.join(title.split()[:5])
            results = ia.search_movie(short_title)
            search_attempts.append(f"Retry with partial: '{short_title}'")

        if not results:
            fuzzy_query = get_close_matches(title.lower(), [t['title'].lower() for t in ia.get_top250_movies()], n=1, cutoff=0.6)
            if fuzzy_query:
                results = ia.search_movie(fuzzy_query[0])
                search_attempts.append(f"Fuzzy match on top250: '{fuzzy_query[0]}'")

        if results:
            match = None
            for movie in results:
                if movie.get('kind') == 'movie':
                    if 'year' in movie and year and abs(movie['year'] - year) > 1:
                        continue
                    match = movie
                    break

            if not match:
                close_matches = get_close_matches(title.lower(), [m.get('title', '').lower() for m in results], n=1, cutoff=0.6)
                for m in results:
                    if m.get('title', '').lower() in close_matches:
                        match = m
                        break

            if match:
                ia.update(match)
                return match, cleaned_title, search_attempts
    except Exception as e:
        logging.error(f"IMDb lookup failed for '{title} ({year})': {e}")
    return None, title, search_attempts

def has_associated_files(base_path):
    base, _ = os.path.splitext(base_path)
    has_image = any(os.path.exists(base + ext) for ext in IMAGE_EXTENSIONS)
    has_sub = any(os.path.exists(base + ext) for ext in SUBTITLE_EXTENSIONS)
    return has_image, has_sub

def write_results_csv():
    with open(CSV_REPORT_FILE, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=['Original Filename', 'New Filename', 'Status', 'Note', 'Image', 'Subtitles', 'Cleaned Title'])
        writer.writeheader()
        for row in results:
            writer.writerow(row)

def main():
    if len(sys.argv) < 2:
        print("Usage: python rename_movies_for_plex.py <folder> [-apply]")
        return

    folder = sys.argv[1]
    apply_changes = '-apply' in sys.argv

    if not os.path.isdir(folder):
        print(f"❌ Folder not found: {folder}")
        return

    logging.info(f"{'APPLYING' if apply_changes else 'Dry run'} in folder: {folder}")

    files = [f for f in os.listdir(folder) if f.lower().endswith(VIDEO_EXTENSIONS)]

    def process_file(filename):
        full_path = os.path.join(folder, filename)
        title, year = extract_title_year(filename)
        movie, cleaned_title, attempts = find_imdb_title(title, year)

        if not movie:
            note = f"No IMDb match | Attempts: {attempts}"
            logging.warning(note)
            skipped.append(filename)
            results.append({
                'Original Filename': filename,
                'New Filename': '',
                'Status': '❌ Skipped',
                'Note': note,
                'Image': False,
                'Subtitles': False,
                'Cleaned Title': cleaned_title
            })
            return

        new_base = f"{movie['title']} ({movie.get('year', '')})"
        _, ext = os.path.splitext(filename)
        new_filename = f"{new_base}{ext}"
        new_path = os.path.join(folder, new_filename)

        has_image, has_sub = has_associated_files(full_path)

        if apply_changes:
            try:
                os.rename(full_path, new_path)
                for ext in IMAGE_EXTENSIONS + SUBTITLE_EXTENSIONS:
                    old_side = os.path.splitext(full_path)[0] + ext
                    if os.path.exists(old_side):
                        os.rename(old_side, os.path.splitext(new_path)[0] + ext)
            except Exception as e:
                logging.error(f"Rename failed for '{filename}': {e}")
                results.append({
                    'Original Filename': filename,
                    'New Filename': '',
                    'Status': '❌ Error',
                    'Note': str(e),
                    'Image': has_image,
                    'Subtitles': has_sub,
                    'Cleaned Title': cleaned_title
                })
                return

        results.append({
            'Original Filename': filename,
            'New Filename': new_filename,
            'Status': '✅ Renamed' if apply_changes else '🔍 Match Found',
            'Note': f"IMDb: {movie['title']} ({movie.get('year', '')})",
            'Image': has_image,
            'Subtitles': has_sub,
            'Cleaned Title': cleaned_title
        })

    with ThreadPoolExecutor(max_workers=MAX_THREADS) as executor:
        futures = [executor.submit(process_file, file) for file in files]
        for future in as_completed(futures):
            future.result()

    write_results_csv()

    with open(SKIPPED_LOG_FILE, 'w') as f:
        for name in skipped:
            f.write(name + '\n')

    logging.info(f"✅ Completed. {len(results) - len(skipped)} renamed, {len(skipped)} skipped.")

if __name__ == '__main__':
    main()
