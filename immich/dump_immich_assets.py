#!/usr/bin/env python3
"""
dump_immich_assets.py - Export All Immich Assets to JSON

Paginates through the Immich /search/metadata endpoint to dump every asset
in your library to a single JSON file. Useful for offline analysis and
cross-referencing with other photo services.

Usage:
    export IMMICH_API_KEY="your-api-key"
    python3 dump_immich_assets.py

Environment variables:
    IMMICH_API_KEY  (required) - Your Immich API key

Output: immich_assets.json
"""
import os, json, urllib.request

BASE = "https://photos.mykk.us/api"
API  = os.environ["IMMICH_API_KEY"]

def call(path, body):
    req = urllib.request.Request(
        f"{BASE}{path}",
        data=json.dumps(body).encode(),
        headers={"Content-Type":"application/json","Accept":"application/json","x-api-key":API},
        method="POST"
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

def main():
    page, size = 1, 1000  # size can be 1..1000
    out = []
    while True:
        resp = call("/search/metadata", {"page": page, "size": size, "withExif": False})
        items = resp.get("assets", {}).get("items", []) if isinstance(resp.get("assets"), dict) else resp.get("assets", [])
        out.extend(items)
        print(f"Fetched page {page} ({len(items)} assets), total {len(out)}")
        if len(items) < size:
            break
        page += 1
    with open("immich_assets.json", "w") as f:
        json.dump(out, f, indent=2)
    print(f"Wrote immich_assets.json with {len(out)} assets")

if __name__ == "__main__":
    main()

