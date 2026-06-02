#!/usr/bin/env python3
"""
compare_files_based_on_hash.py - Sync New Files by Hash Comparison

Compares files in a source directory against a destination directory tree
using MD5 hashes. Files not found in the destination are copied to an
inbox folder. Supports --dry-run to preview without copying.

Usage:
    python3 compare_files_based_on_hash.py --source /path/to/source --dest /path/to/dest --inbox /path/to/inbox [--dry-run]
"""
import os
import hashlib
import shutil
import argparse


def get_file_hash(path):
    """Generates an MD5 hash for a file fingerprint."""
    hasher = hashlib.md5()
    try:
        if not os.path.isfile(path):
            return None
        with open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hasher.update(chunk)
        return hasher.hexdigest()
    except (OSError, IOError):
        return None


def sync_logic(source_dir, dest_dir, inbox_dir, dry_run):
    if dry_run:
        print("--- DRY RUN ENABLED: No files will be copied ---")

    # 1. Index Destination Content (Recursive)
    print(f"Indexing destination: {dest_dir}...")
    dest_hashes = set()
    for root, _, files in os.walk(dest_dir):
        for file in files:
            if file.startswith('.'):
                continue
            f_hash = get_file_hash(os.path.join(root, file))
            if f_hash:
                dest_hashes.add(f_hash)

    print(f"Found {len(dest_hashes)} unique files in destination.")

    # 2. Scan Source (Flat Folder)
    print(f"Checking source: {source_dir}")

    if not dry_run and not os.path.exists(inbox_dir):
        os.makedirs(inbox_dir)

    for file in os.listdir(source_dir):
        if file.startswith('.'):
            continue

        src_path = os.path.join(source_dir, file)

        if not os.path.isfile(src_path):
            continue

        src_hash = get_file_hash(src_path)

        if not src_hash:
            continue

        if src_hash not in dest_hashes:
            final_path = os.path.join(inbox_dir, file)

            # Handle filename collisions in Inbox
            if os.path.exists(final_path):
                name, ext = os.path.splitext(file)
                final_path = os.path.join(inbox_dir, f"{name}_{src_hash[:6]}{ext}")

            print(f"[NEW -> INBOX] {file}")

            if not dry_run:
                shutil.copy2(src_path, final_path)

            dest_hashes.add(src_hash)
        else:
            print(f"[EXISTS] Skipping: {file}")


def parse_args():
    p = argparse.ArgumentParser(
        description="Compare source files against destination by hash and copy new files to inbox."
    )
    p.add_argument("--source", required=True, help="Source directory to scan (flat)")
    p.add_argument("--dest", required=True, help="Destination directory to index (recursive)")
    p.add_argument("--inbox", required=True, help="Inbox directory for new files")
    p.add_argument("--dry-run", action="store_true", help="Preview changes without copying files")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    sync_logic(args.source, args.dest, args.inbox, args.dry_run)
    if args.dry_run:
        print("\nDry run complete. Remove --dry-run to execute.")
    else:
        print("\nSync complete.")
