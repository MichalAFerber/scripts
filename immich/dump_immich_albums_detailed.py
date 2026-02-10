#!/usr/bin/env python3
"""
dump_immich_albums_detailed.py - Export Immich Albums with Filenames to JSON

Like dump_immich_albums.py but includes originalFileName for each asset,
enabling filename-based matching against other photo services (e.g., Ente).

Usage:
    export IMMICH_API_KEY="your-api-key"
    python3 dump_immich_albums_detailed.py

Environment variables:
    IMMICH_API_KEY  (required) - Your Immich API key
    IMMICH_URL      (optional) - Immich API base URL (default: https://photos.mykk.us/api)

Output: immich_albums_detailed.json
"""
import os, json, urllib.request, time
BASE = os.environ.get("IMMICH_URL","https://photos.mykk.us/api")
API  = os.environ["IMMICH_API_KEY"]
HEAD = {"Accept":"application/json","x-api-key":API}

def get(url):
    req = urllib.request.Request(url, headers=HEAD)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())

def main():
    albums = get(f"{BASE}/albums")
    out = []
    for a in albums:
        info = get(f"{BASE}/albums/%s?withoutAssets=false" % a["id"])
        assets = info.get("assets", [])
        out.append({
            "id": a["id"],
            "name": a.get("albumName"),
            "assets": [{"id": x["id"], "originalFileName": x.get("originalFileName")} for x in assets]
        })
        print(f"{a.get('albumName')} -> {len(assets)}")
        time.sleep(0.05)
    with open("immich_albums_detailed.json","w") as f:
        json.dump(out, f, indent=2)
    print("Wrote immich_albums_detailed.json")
if __name__ == "__main__":
    main()
