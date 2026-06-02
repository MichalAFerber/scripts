#!/usr/bin/env python3
"""
s3_backup.py - Upload a Local Folder to an S3-Compatible Bucket

Recursively walks a local directory and uploads every file to an S3 bucket
using boto3. Files are keyed by their relative path under an optional prefix.

Usage:
    export AWS_ACCESS_KEY_ID="your-key"
    export AWS_SECRET_ACCESS_KEY="your-secret"
    python3 s3_backup.py /path/to/folder bucket-name [prefix] [--dry-run]

Arguments:
    1. Local folder path to upload
    2. S3 bucket name
    3. (Optional) Key prefix in the bucket
    --dry-run   Show what would be uploaded without actually uploading

Prerequisites:
    pip install boto3
    AWS credentials set via environment variables or ~/.aws/credentials

Note: This performs a simple full upload on every run. It does not skip
unchanged files -- for incremental sync, consider rclone or aws s3 sync.
"""
import boto3, os, sys, hashlib
from pathlib import Path

# Parse --dry-run flag
dry_run = "--dry-run" in sys.argv
args = [a for a in sys.argv[1:] if a != "--dry-run"]

if len(args) < 2:
    print("Usage: python3 s3_backup.py /path/to/folder bucket-name [prefix] [--dry-run]")
    sys.exit(1)

local = Path(args[0])
bucket = args[1]
prefix = args[2] if len(args) > 2 else ''

if not local.is_dir():
    print(f"ERROR: Source not found or not a directory: {local}")
    sys.exit(1)

if dry_run:
    print("[DRY RUN] No files will be uploaded.")

s3 = boto3.client('s3')

def md5(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            h.update(chunk)
    return h.hexdigest()

count = 0
for p in local.rglob('*'):
    if p.is_file():
        key = (prefix + '/' + str(p.relative_to(local))).lstrip('/')
        if dry_run:
            print(f"[DRY RUN] Would upload: {key}")
        else:
            s3.upload_file(str(p), bucket, key)
            print("Uploaded", key)
        count += 1

if dry_run:
    print(f"\n[DRY RUN] {count} file(s) would be uploaded.")
else:
    print(f"\n{count} file(s) uploaded.")
