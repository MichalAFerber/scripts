# dump_immich_albums
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Fetches every album from an Immich instance and writes a JSON file containing each album's ID, name, and list of asset IDs. Useful for auditing album contents and scripting bulk operations.
### How to Use
```bash
export IMMICH_API_KEY="your-api-key"
python3 dump_immich_albums.py
```
Optionally set a custom server URL:
```bash
export IMMICH_URL="https://your-immich-host/api"
```
Produces `immich_albums.json` in the current directory.

Dependencies: Python 3 standard library only (no pip packages). Requires network access to the Immich server.
### What and Where to Tweak
- `IMMICH_URL` environment variable or default in the script: Change to point to your Immich server.
- Output filename: Change `"immich_albums.json"` in `main()` to write to a different path.
- The script fetches full asset lists per album (`withoutAssets=false`). For large libraries with many albums, this can take a while.
