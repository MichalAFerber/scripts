#!/usr/bin/env python3
"""
sync_folders.py - Basic Two-Way Folder Synchronization

Sync two folders using rsync

Author: Michal A. Ferber
License: MIT
Repo: https://github.com/MichalAFerber/scripts

Usage:
    - python3 sync_folders.py /mnt/storage1/books /mnt/storage2/books
    - Or to preview without making changes
    - python3 sync_folders.py /mnt/storage1/books /mnt/storage2/books --dry-run
"""

import subprocess
import logging
import sys
import os
import argparse
from datetime import datetime

log_filename = f'sync_log_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_filename),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

def sync_folders(source, destination, options):
    try:
        if not source.endswith('/'):
            source += '/'
        if not destination.endswith('/'):
            destination += '/'

        rsync_cmd = ['rsync'] + options + [source, destination]

        logger.info(f"Syncing: {source} ➡️ {destination}")
        result = subprocess.run(rsync_cmd, capture_output=True, text=True)

        if result.returncode == 0:
            logger.info("✔ Sync completed successfully")
            return True
        else:
            logger.error(f"❌ Sync failed with return code {result.returncode}")
            logger.error(result.stderr)
            return False

    except subprocess.CalledProcessError as e:
        logger.error(f"Error during rsync: {str(e)}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Two-way folder synchronization using rsync.")
    parser.add_argument("src_folder", help="Source folder path")
    parser.add_argument("dest_folder", help="Destination folder path")
    parser.add_argument("--dry-run", action="store_true", help="Simulate the sync without making changes")
    parser.add_argument("--help-md", action="store_true", help="Show Markdown-formatted help and exit")

    args = parser.parse_args()

    if args.help_md:
        print_docs()
        sys.exit(0)

    forward_options = ['-av', '--delete']
    reverse_options = ['-av', '--update', '--ignore-existing']
    if args.dry_run:
        forward_options.append('--dry-run')
        reverse_options.append('--dry-run')

    logger.info("=== Starting folder synchronization ===")

    if sync_folders(args.src_folder, args.dest_folder, forward_options):
        logger.info("✔ Source ➝ Destination sync complete")
    else:
        logger.error("❌ Source ➝ Destination sync failed")
        sys.exit(1)

    if sync_folders(args.dest_folder, args.src_folder, reverse_options):
        logger.info("✔ Destination ➝ Source sync complete")
    else:
        logger.error("❌ Destination ➝ Source sync failed")
        sys.exit(1)

    logger.info("✅ Two-way folder synchronization complete")
    logger.info(f"📄 Log saved to: {os.path.abspath(log_filename)}")

def print_docs():
    doc = """# 🗂️ sync_folders.py

Basic Two-Way Folder Synchronization using rsync.

**Author**: Michal A. Ferber  
**License**: MIT  
**Repo**: https://github.com/MichalAFerber/scripts

## 🔧 Usage

```bash
python3 sync_folders.py /mnt/storage1/books /mnt/storage2/books
python3 sync_folders.py /mnt/storage1/books /mnt/storage2/books --dry-run
```

- Uses `rsync -av --delete` under the hood.
- Performs **bidirectional sync**.
- Logs output to a timestamped file.
"""
    print(doc)

if __name__ == '__main__':
    main()
