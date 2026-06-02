# sync_folders_option1
## Michal Ferber
## Revised Date: 03/27/2026
### Description
A Python script that performs bidirectional folder synchronization using rsync. The forward pass (`rsync -av --delete`) mirrors the source to the destination, deleting files in the destination that no longer exist in the source. The reverse pass (`rsync -av --update --ignore-existing`) copies any new files from the destination back to the source without overwriting. All activity is logged to a timestamped file.
### How to Use
```bash
# Two-way sync between two folders
python3 sync_folders_option1.py /mnt/storage1/books /mnt/storage2/books

# Preview what would happen without making changes
python3 sync_folders_option1.py /mnt/storage1/books /mnt/storage2/books --dry-run

# Print built-in markdown documentation
python3 sync_folders_option1.py /mnt/storage1/books /mnt/storage2/books --help-md
```
Prerequisites: Python 3, rsync installed.
### What and Where to Tweak
- `log_filename` (line 24): Change the log file name pattern or directory.
- `forward_options` (line 76): Adjust rsync flags for source-to-destination sync (e.g., add `--exclude` patterns).
- `reverse_options` (line 77): Adjust rsync flags for destination-to-source sync.
