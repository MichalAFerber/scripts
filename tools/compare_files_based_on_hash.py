#!/usr/bin/env python3
import os
import hashlib
import shutil

# --- CONFIGURATION ---
SOURCE_DIR = '/Volumes/Mando/application_backups/Paperless-ngx/2025-12-26 Paperless-ngx export'
DEST_DIR = '/Volumes/Mando/_stor'
INBOX_DIR = '/Volumes/Mando/_stor/_Inbox'
DRY_RUN = False  # Set to True or False
# ---------------------

def get_file_hash(path):
    """Generates an MD5 hash for a file fingerprint."""
    hasher = hashlib.md5()
    try:
        # Check if it's a file (skips directories/symlinks)
        if not os.path.isfile(path):
            return None
        with open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hasher.update(chunk)
        return hasher.hexdigest()
    except (OSError, IOError):
        return None

def sync_logic():
    if DRY_RUN:
        print("--- DRY RUN ENABLED: No files will be moved ---")

    # 1. Index Destination Content (Recursive)
    print(f"Indexing destination: {DEST_DIR}...")
    dest_hashes = set()
    for root, _, files in os.walk(DEST_DIR):
        for file in files:
            # Skip hidden files like .DS_Store
            if file.startswith('.'): continue
            
            f_hash = get_file_hash(os.path.join(root, file))
            if f_hash:
                dest_hashes.add(f_hash)

    print(f"Found {len(dest_hashes)} unique files in destination.")

    # 2. Scan Source (Flat Folder)
    print(f"Checking source: {SOURCE_DIR}")
    
    # Ensure Inbox exists if not dry run
    if not DRY_RUN and not os.path.exists(INBOX_DIR):
        os.makedirs(INBOX_DIR)

    for file in os.listdir(SOURCE_DIR):
        if file.startswith('.'): continue
        
        src_path = os.path.join(SOURCE_DIR, file)
        
        # Only process files
        if not os.path.isfile(src_path):
            continue
            
        src_hash = get_file_hash(src_path)

        if not src_hash:
            continue

        # If content is NOT found anywhere in DEST_DIR
        if src_hash not in dest_hashes:
            # Since source is flat, we always send new files to Inbox
            final_path = os.path.join(INBOX_DIR, file)
            
            # Handle filename collisions in Inbox (e.g., two different files named "Doc.pdf")
            if os.path.exists(final_path):
                name, ext = os.path.splitext(file)
                final_path = os.path.join(INBOX_DIR, f"{name}_{src_hash[:6]}{ext}")

            print(f"[NEW -> INBOX] {file}")

            if not DRY_RUN:
                shutil.copy2(src_path, final_path)
            
            # Add to set so we don't copy the same content twice in one session
            dest_hashes.add(src_hash)
        else:
            print(f"[EXISTS] Skipping: {file}")

if __name__ == "__main__":
    sync_logic()
    if DRY_RUN:
        print("\nDry run complete. Change DRY_RUN = False to execute.")
    else:
        print("\nSync complete.")