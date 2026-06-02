# compare_ente_to_immich
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Compares albums between an Ente export (via export_status.json) and an Immich album dump (via immich_albums_detailed.json) using exact filename matching. Produces a CSV report showing matched, mismatched, and missing albums along with file counts.
### How to Use
```bash
# Basic usage with default file paths
python3 compare_ente_to_immich.py --ente export_status.json --immich immich_albums_detailed.json

# With album name mapping and custom output
python3 compare_ente_to_immich.py --ente export_status.json --immich immich_albums_detailed.json --map album_map.csv --out comparison.csv
```
Flags:
- `--ente`: Path to Ente's `export_status.json` (default: `export_status.json`)
- `--immich`: Path to Immich detailed albums JSON (default: `immich_albums_detailed.json`)
- `--map`: Optional CSV with columns `ente_album,immich_album` to map differing album names
- `--out`: Output CSV path (default: `album_comparison.csv`)

Prerequisites: Run `dump_immich_albums_detailed.py` first to generate the Immich JSON. Have the Ente `export_status.json` from an Ente export.

Dependencies: Python 3 standard library only (no pip packages).
### What and Where to Tweak
- Album name mapping CSV: Create a file with `ente_album,immich_album` columns to handle albums with different names across services.
- The comparison is case-insensitive on filenames. All basenames are lowercased before comparison.
- The script reports Immich-only albums (up to 20) in the console output. Adjust the `[:20]` slice to show more.
