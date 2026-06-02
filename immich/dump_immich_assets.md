# dump_immich_assets
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Exports every asset from an Immich instance to a single JSON file by paginating through the /search/metadata API endpoint. Useful for offline analysis, auditing, and cross-referencing with other photo services.
### How to Use
```bash
export IMMICH_API_KEY="your-api-key"
python3 dump_immich_assets.py
```
Produces `immich_assets.json` in the current directory.

Dependencies: Python 3 standard library only (no pip packages). Requires network access to the Immich server.
### What and Where to Tweak
- `BASE` (top of file): The Immich API base URL. Change to match your server (e.g., `https://your-immich-host/api`).
- `size` in `main()`: Page size for API requests (1-1000). Reduce if you hit timeouts on large libraries.
- `withExif` in the API call body: Set to `True` to include EXIF metadata in the export (increases file size significantly).
- Output filename: Change `"immich_assets.json"` in `main()` to write to a different path.
