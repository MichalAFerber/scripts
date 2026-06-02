#!/usr/bin/env python3
"""
dump_immich_albums.py - Export All Immich Albums to JSON

Fetches every album from your Immich instance and writes a JSON file
containing album IDs, names, and their asset IDs.

Usage:
    export IMMICH_API_KEY="your-api-key"
    python3 dump_immich_albums.py

Environment variables:
    IMMICH_API_KEY  (required) - Your Immich API key
    IMMICH_URL      (optional) - Immich API base URL (default: https://photos.mykk.us/api)

Output: immich_albums.json
"""
import os, json, urllib.request

IMMICH_URL = os.environ.get("IMMICH_URL", "https://photos.mykk.us/api")
API_KEY    = os.environ["IMMICH_API_KEY"]

def get(url):
    req = urllib.request.Request(
        url, headers={"Accept":"application/json","x-api-key":API_KEY}
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

def main():
    albums = get(f"{IMMICH_URL}/albums")  # getAllAlbums
    out = []
    for a in albums:
        info = get(f"{IMMICH_URL}/albums/{a['id']}?withoutAssets=false")  # getAlbumInfo
        out.append({"id": a["id"], "name": a.get("albumName"), "assetIds": [x["id"] for x in info.get("assets", [])]})
        print(f"Album: {a.get('albumName')} -> {len(out[-1]['assetIds'])} assets")
    with open("immich_albums.json","w") as f:
        json.dump(out, f, indent=2)
    print("Wrote immich_albums.json")

if __name__ == "__main__":
    main()
