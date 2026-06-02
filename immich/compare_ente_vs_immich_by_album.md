# compare_ente_vs_immich_by_album
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Performs a one-way album-by-album comparison from an Ente export to Immich. Scans the Ente export folder structure (each subfolder = an album) and compares filenames against an Immich detailed album JSON dump. Supports both strict (exact filename) and loose (stem/timestamp-based) matching modes. Writes a summary CSV and per-album missing-file lists.
### How to Use
```bash
# Strict comparison (exact filename match)
python3 compare_ente_vs_immich_by_album.py --ente /path/to/export_status.json --immich immich_albums_detailed.json

# Loose comparison (tolerates renamed files, duplicate suffixes, timestamp matching)
python3 compare_ente_vs_immich_by_album.py --ente /path/to/export_status.json --immich immich_albums_detailed.json --loose

# With album name mapping and skip list
python3 compare_ente_vs_immich_by_album.py \
    --ente /path/to/export_status.json \
    --immich immich_albums_detailed.json \
    --map album_map.csv \
    --skip-ente skip_ente.txt \
    --loose
```
Flags:
- `--ente` (required): Path to Ente's `export_status.json` (parent folder is scanned for album subfolders)
- `--immich` (required): Path to `immich_albums_detailed.json` (from `dump_immich_albums_detailed.py`)
- `--map`: Optional CSV mapping Ente album names to Immich album names (comma-separated, one pair per line)
- `--skip-ente`: Optional text file listing Ente album names to skip (one per line)
- `--out`: Output CSV path (default: `album_comparison.csv`)
- `--diff-dir`: Directory for per-album `*_missing.txt` files (default: `album_diffs`)
- `--loose`: Enable loose matching (strip suffixes, match by timestamp/stem)

Environment variables:
- `COMPARE_LOOSE=1`: Enable loose mode without the CLI flag
- `COMPARE_EXPLAIN=1`: Write detailed explain files showing how loose matching resolved each miss

Prerequisites: Run `dump_immich_albums_detailed.py` first. Have the Ente export folder with `export_status.json`.

Dependencies: Python 3 standard library only (no pip packages).
### What and Where to Tweak
- `ALLOWED_EXTS`: Set of file extensions considered as media. Add or remove extensions as needed.
- `_LOOSE_PREFIX_RE`: Regex for camera prefixes stripped during loose matching (img, dsc, pxl, scan, photo, picture). Add your camera's prefix pattern here.
- `_strip_edited()`: Patterns for non-semantic suffixes (edited, copy, version numbers). Extend if your workflow adds other suffixes.
- `_TS_PATTERNS`: Timestamp extraction regexes for matching files by embedded date/time. Add patterns if your filenames use unusual timestamp formats.
- `limit` in `_write_explain()`: Number of misses shown in explain files (default: 12).
