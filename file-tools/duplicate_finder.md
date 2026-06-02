# duplicate_finder
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Scans one or more directories for duplicate files using a two-pass approach: first groups files by size, then hashes only size-matched candidates with MD5. Provides an interactive menu to view duplicates, export a JSON report, and optionally delete duplicates (with dry-run as the default).
### How to Use
```bash
python3 duplicate_finder.py ~/Downloads ~/Documents
```
The interactive menu offers:
1. Show duplicate summary (counts and wasted space)
2. Show all duplicate sets with file paths
3. Export report to a JSON file
4. Delete duplicates -- dry run (shows what would be deleted, no files removed)
5. Delete duplicates -- permanent (requires typing DELETE to confirm)
6. Exit

Deletion defaults to dry-run mode. Option 5 requires explicit confirmation.

Dependencies: Python 3 standard library only (no pip packages).
### What and Where to Tweak
- `min_size` (line in `__main__`): Currently set to 1024 bytes (1 KB). Increase to skip small files, or set to 0 to include everything.
- `keep` strategy in `delete_duplicates()`: Choose from `first`, `last`, `smallest_path`, or `newest` to control which copy survives.
- Hash algorithm: Uses MD5 via `_calculate_hash()`. Swap to `hashlib.sha256()` if needed.
