# dump_immich_albums_detailed
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Exports all Immich albums with per-asset original filenames to a JSON file. Unlike the basic album dump, this version includes `originalFileName` for each asset, enabling filename-based matching against other photo services like Ente.
### How to Use
```bash
export IMMICH_API_KEY="your-api-key"
python3 dump_immich_albums_detailed.py
```
Optionally set a custom server URL:
```bash
export IMMICH_URL="https://your-immich-host/api"
```
Produces `immich_albums_detailed.json` in the current directory.

Dependencies: Python 3 standard library only (no pip packages). Requires network access to the Immich server.
### What and Where to Tweak
- `BASE` / `IMMICH_URL` environment variable: Change to point to your Immich server.
- `time.sleep(0.05)`: Rate-limiting delay between album fetches. Increase if your server is slow or decrease/remove if it handles load well.
- Output filename: Change `"immich_albums_detailed.json"` in `main()` to write to a different path.
- The asset fields extracted are `id` and `originalFileName`. Add more fields from the API response (e.g., `fileCreatedAt`, `type`) by extending the list comprehension in `main()`.
