#!/usr/bin/env python3
"""
rename_comics.py - Kavita Comic Renamer

Renames comic files to match Kavita's recommended metadata format:
  Title - Year - Issue.ext
Handles special issues, backs up originals, and flattens folders.

Author: Michal A. Ferber
License: MIT
Repo: https://github.com/MichalAFerber/scripts

Usage:
    - Set the BASE_DIR to your comic library root folder
    - Run: python3 rename_comics.py
    - Renamed files will be backed up to BACKUP_DIR
"""

import os
import shutil
import re

# CONFIGURATION
BASE_DIR = "/mnt/ferber-storage/booklore/books/comics"
BACKUP_DIR = "/mnt/ferber-storage/booklore/books/comics_backup"
YEAR_MAPPING = {
    "Amazing-Man Comics": {
        "007": "1939", "008": "1939", "009": "1940", "010": "1940", "011": "1940",
        "012": "1940", "013": "1940", "014": "1940", "015": "1941", "016": "1941",
        "017": "1941", "018": "1941", "019": "1941", "020": "1941", "021": "1941",
        "022": "1941", "023": "1941", "024": "1941", "025": "1941", "026": "1942"
    },
    "The Spirit": {
        "001": "1952", "002": "1952", "003": "1952", "004": "1953", "005": "1953"
    },
    "1000 Jokes Magazine": {"39a": "1946"},
    "Army and Navy Jokes": {"06": "1945", "07": "1945"},
    "Captain Marvel Adventures": {"001": "1941"},
    "Cartoon Cuties": {"003": "1955"},
    "Give My Regards to Black Jack": {"002": "2002"},
    "Howl": {"001": "1944"},
    "Strange Worlds": {"01": "1950", "02": "1951"},
    "Superman": {"017": "2024"},
    "T.N.T": {"002": "1954"},
    "Ultimate Spider-Man": {"008": "2024"}
}

def get_year_from_filename(magazine, filename):
    """Get year based on filename or YEAR_MAPPING override"""
    base = os.path.splitext(filename)[0]
    if magazine in YEAR_MAPPING:
        for key, year in YEAR_MAPPING[magazine].items():
            if key in base:
                return year
    match = re.search(r'(\d{4})', base)
    return match.group(1) if match else "2023"

def is_special_file(filename):
    """Detect if file lacks a clear issue number"""
    base = os.path.splitext(filename)[0]
    return not re.search(r'\d{2,3}$|vol \d+|#\d+', base, re.IGNORECASE)

def rename_files(magazine_folder):
    """Rename all files in one magazine folder"""
    os.makedirs(BACKUP_DIR, exist_ok=True)

    for root, dirs, files in os.walk(magazine_folder):
        rel_path = os.path.relpath(root, BASE_DIR)
        backup_root = os.path.join(BACKUP_DIR, rel_path)
        os.makedirs(backup_root, exist_ok=True)

        for file in files:
            old_path = os.path.join(root, file)
            shutil.copy2(old_path, os.path.join(backup_root, file))

            base, ext = os.path.splitext(file)
            magazine_name = os.path.basename(magazine_folder)

            if is_special_file(file):
                new_base = f"{magazine_name} - {get_year_from_filename(magazine_name, base)} - Special - {base}"
            else:
                issue_match = re.search(r'vol (\d+)|#(\d+)|(\d{2,3})', base, re.IGNORECASE)
                issue = issue_match.group(1) or issue_match.group(2) or issue_match.group(3) or "01"
                try:
                    issue_num = int(issue)
                    year = get_year_from_filename(magazine_name, base)
                    new_base = f"{magazine_name} - {year} - {issue_num:02d}"
                except ValueError:
                    new_base = f"{magazine_name} - {get_year_from_filename(magazine_name, base)} - {issue}"

            new_path = os.path.join(magazine_folder, f"{new_base}{ext}")
            counter = 1
            while os.path.exists(new_path):
                new_path = os.path.join(magazine_folder, f"{new_base}_{counter}{ext}")
                counter += 1

            os.rename(old_path, new_path)
            print(f"Renamed: {file} -> {os.path.basename(new_path)}")

        # Flatten any subfolders
        for dir_name in dirs:
            subfolder = os.path.join(root, dir_name)
            for item in os.listdir(subfolder):
                item_path = os.path.join(subfolder, item)
                if os.path.isfile(item_path):
                    shutil.move(item_path, magazine_folder)
            os.rmdir(subfolder)

# MAIN LOOP
for magazine in os.listdir(BASE_DIR):
    path = os.path.join(BASE_DIR, magazine)
    if os.path.isdir(path):
        rename_files(path)

print("✅ Renaming and reorganization complete. Backups saved.")
