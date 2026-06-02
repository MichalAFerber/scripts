# sync_folders
## Michal Ferber
## Revised Date: 03/27/2026
### Description
A shell wrapper that launches `sync_folders.py` to perform a bidirectional (two-way) folder sync using rsync. It passes all command-line arguments through to the Python script. The forward pass uses `rsync -av --delete` and the reverse pass uses `rsync -av --update --ignore-existing`, so files deleted on the source side are removed from the destination, while new files on the destination side are copied back.
### How to Use
```bash
# Two-way sync between two folders
./sync_folders.sh /mnt/storage1/books /mnt/storage2/books

# Preview what would happen without making changes
./sync_folders.sh /mnt/storage1/books /mnt/storage2/books --dry-run
```
Prerequisites: Python 3, rsync installed, and `sync_folders.py` in the same directory.
### What and Where to Tweak
- The script itself has no configurable variables; all configuration is in `sync_folders.py`.
- In `sync_folders.py`, the rsync options for forward sync (`-av --delete`) and reverse sync (`-av --update --ignore-existing`) can be adjusted in the `main()` function.
- The log file name pattern (`sync_log_YYYYMMDD_HHMMSS.log`) is set at the top of the Python script.
