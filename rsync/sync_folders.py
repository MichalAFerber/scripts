# Suggested Usage
# python3 sync_folders.py /mnt/storage1/books /mnt/storage2/books
# Or to preview without making changes:
# python3 sync_folders.py /mnt/storage1/books /mnt/storage2/books --dry-run

#!/usr/bin/env python3
import subprocess
import logging
import sys
import os
import argparse
from datetime import datetime

# Create log file with timestamp
log_filename = f'sync_log_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'

# Configure logging
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
    """
    Synchronize two folders using rsync.

    Args:
        source (str): Source folder path
        destination (str): Destination folder path
        options (list): Additional rsync options
    Returns:
        bool: True if sync successful, False otherwise
    """
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

    args = parser.parse_args()
    options = ['-av', '--delete']
    if args.dry_run:
        options.append('--dry-run')

    logger.info("=== Starting folder synchronization ===")

    if sync_folders(args.src_folder, args.dest_folder, options):
        logger.info("✔ Source ➝ Destination sync complete")
    else:
        logger.error("❌ Source ➝ Destination sync failed")
        sys.exit(1)

    if sync_folders(args.dest_folder, args.src_folder, options):
        logger.info("✔ Destination ➝ Source sync complete")
    else:
        logger.error("❌ Destination ➝ Source sync failed")
        sys.exit(1)

    logger.info("✅ Two-way folder synchronization complete")
    logger.info(f"📄 Log saved to: {os.path.abspath(log_filename)}")

if __name__ == '__main__':
    main()
