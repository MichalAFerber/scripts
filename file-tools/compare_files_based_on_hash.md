# compare_files_based_on_hash
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Compares files in a flat source directory against an entire destination directory tree using MD5 hashes. Any source file whose content is not already present anywhere in the destination is copied into a designated inbox folder. Filename collisions in the inbox are resolved by appending a short hash suffix.
### How to Use
```bash
# Preview what would be copied (no files are moved)
python3 compare_files_based_on_hash.py --source /path/to/source --dest /path/to/dest --inbox /path/to/dest/_Inbox --dry-run

# Actually copy new files to inbox
python3 compare_files_based_on_hash.py --source /path/to/source --dest /path/to/dest --inbox /path/to/dest/_Inbox
```
Flags:
- `--source` (required): Flat directory of files to check
- `--dest` (required): Destination directory tree to index (scanned recursively)
- `--inbox` (required): Directory where new files are copied
- `--dry-run`: Show what would be copied without actually copying

Dependencies: Python 3 standard library only (no pip packages).
### What and Where to Tweak
- The hash algorithm is MD5 (adequate for dedup, not for security). Change `hashlib.md5()` in `get_file_hash()` if you need SHA-256.
- Hidden files (names starting with `.`) are skipped. Adjust the `startswith('.')` checks if needed.
- Source scanning is flat (non-recursive). If you need recursive source scanning, replace `os.listdir` with `os.walk`.
