#!/usr/bin/env python3
"""
rename_magazines.py

Renames magazine files to follow Kavita's "Title - Year - Issue" format,
optionally appending "Special" where issue numbers are unclear.

Usage:
    python rename_magazines.py --base-dir /path/to/magazines --backup-dir /path/to/backup

Defaults:
    BASE_DIR = "/mnt/ferber-storage/booklore/books/magazines"
    BACKUP_DIR = "/mnt/ferber-storage/booklore/books/magazines_backup"

License: MIT
Author: Michal A. Ferber (https://github.com/MichalAFerber)
"""

import os
import shutil
import re
import argparse
import logging

# Year mapping for special cases or known magazine issues
YEAR_MAPPING = {
    "MagPi Magazine": {str(i).zfill(3): str(2012 + (i - 1) // 12) for i in range(1, 151)},
    "Raspberry Pi Official Magazine": {
        "151": "2025", "152": "2025", "153": "2025", "154": "2025", "155": "2025"
    },
    "Custom PC Magazine": {str(i): "2023" for i in range(214, 235)},
    # Add more mappings here
}

def setup_logging():
    """Configure logging to console."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s"
    )

def get_year_from_filename(magazine: str, filename: str) -> str:
    """Returns the year using predefined mappings or regex fallback."""
    base = os.path.splitext(filename)[0]
    if magazine in YEAR_MAPPING:
        for key, year in YEAR_MAPPING[magazine].items():
            if key in base:
                return year
    match = re.search(r'(\d{4})', base)
    return match.group(1) if match else "2023"

def is_special_file(filename: str) -> bool:
    """Determines if file lacks clear issue number, marking it as 'Special'."""
    base = os.path.splitext(filename)[0]
    return not re.search(r'vol \d+|#\d+|\d{2,3}$', base, re.IGNORECASE)

def rename_files(magazine_folder: str, base_dir: str, backup_dir: str):
    """Processes and renames files in the specified magazine folder."""
    magazine_name = os.path.basename(magazine_folder)
    for root, dirs, files in os.walk(magazine_folder):
        rel_path = os.path.relpath(root, base_dir)
        backup_root = os.path.join(backup_dir, rel_path)
        os.makedirs(backup_root, exist_ok=True)

        for file in files:
            old_path = os.path.join(root, file)
            backup_path = os.path.join(backup_root, file)
            shutil.copy2(old_path, backup_path)

            base_name, ext = os.path.splitext(file)

            if is_special_file(file) or "Specials" in root:
                new_base = f"{magazine_name} - {get_year_from_filename(magazine_name, base_name)} - Special - {base_name}"
            else:
                issue_match = re.search(r'vol (\d+)|#(\d+)|(\d{2,3})$', base_name, re.IGNORECASE)
                issue = issue_match.group(1) or issue_match.group(2) or issue_match.group(3) if issue_match else "01"
                try:
                    issue_num = int(issue)
                    year = get_year_from_filename(magazine_name, base_name)
                    new_base = f"{magazine_name} - {year} - {issue_num:02d}"
                except ValueError:
                    new_base = f"{magazine_name} - {get_year_from_filename(magazine_name, base_name)} - {issue}"

            new_path = os.path.join(magazine_folder, f"{new_base}{ext}")
            counter = 1
            while os.path.exists(new_path):
                new_path = os.path.join(magazine_folder, f"{new_base}_{counter}{ext}")
                counter += 1

            os.rename(old_path, new_path)
            logging.info(f"Renamed: {file} -> {os.path.basename(new_path)}")

        # Move contents from subfolders up and remove the empty folder
        for dir_name in dirs:
            subfolder = os.path.join(root, dir_name)
            for item in os.listdir(subfolder):
                item_path = os.path.join(subfolder, item)
                if os.path.isfile(item_path):
                    shutil.move(item_path, magazine_folder)
            os.rmdir(subfolder)

def main():
    setup_logging()

    parser = argparse.ArgumentParser(description="Rename magazine files to Kavita format.")
    parser.add_argument('--base-dir', default="/mnt/ferber-storage/booklore/books/magazines", help="Directory containing magazine folders")
    parser.add_argument('--backup-dir', default="/mnt/ferber-storage/booklore/books/magazines_backup", help="Directory to store backups")
    args = parser.parse_args()

    base_dir = args.base_dir
    backup_dir = args.backup_dir

    if not os.path.exists(base_dir):
        logging.error(f"Base directory does not exist: {base_dir}")
        return

    os.makedirs(backup_dir, exist_ok=True)

    for magazine in os.listdir(base_dir):
        path = os.path.join(base_dir, magazine)
        if os.path.isdir(path):
            logging.info(f"Processing: {magazine}")
            rename_files(path, base_dir, backup_dir)

    logging.info("Renaming complete. Backups saved.")

if __name__ == "__main__":
    main()
