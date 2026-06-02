# s3_backup
## Michal Ferber
## Revised Date: 03/27/2026
### Description
A simple Python script that recursively uploads every file in a local directory to an S3-compatible bucket using boto3. Files are keyed by their relative path under an optional prefix. This is a full upload on every run -- it does not skip unchanged files.
### How to Use
```bash
# Set credentials
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

# Upload a folder
python3 s3_backup.py /path/to/folder bucket-name

# Upload with a key prefix
python3 s3_backup.py /path/to/folder bucket-name "backups/2026-03-27"

# Dry run to see what would be uploaded
python3 s3_backup.py /path/to/folder bucket-name --dry-run
```
**Prerequisites:**
- Python 3
- `boto3` (`pip install boto3`)
- AWS/S3 credentials set via environment variables or `~/.aws/credentials`
- For Wasabi, set the `AWS_DEFAULT_REGION` and endpoint URL in your boto3 config
### What and Where to Tweak
- The S3 endpoint is determined by your boto3/AWS configuration -- for Wasabi, configure the endpoint URL in `~/.aws/config` or via environment variables
- For incremental sync (skip unchanged files), consider using `rclone` or `aws s3 sync` instead
- The `md5()` function is defined but not currently used for change detection -- it could be extended to compare checksums before uploading
