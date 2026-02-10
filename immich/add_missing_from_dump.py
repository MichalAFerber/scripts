#!/usr/bin/env python3
"""
add_missing_from_dump.py - Add Missing Assets to an Immich Album (from dump)

Reads a previously exported immich_albums_detailed.json dump and a missing-files
list, then matches filenames (with extension-twin and basename fallbacks) and
adds the found assets to the target Immich album via API.

Usage:
    export IMMICH_API_KEY="your-api-key"
    python3 add_missing_from_dump.py immich_albums_detailed.json 'Album Name' album_diffs/missing.txt

Arguments:
    1. Path to immich_albums_detailed.json (from dump_immich_albums_detailed.py)
    2. Target Immich album name (must exist in the dump)
    3. Path to a missing-files text list (one filename per line)

Environment variables:
    IMMICH_API_KEY  (required) - Your Immich API key
    IMMICH_URL      (optional) - Immich API base URL (default: https://photos.mykk.us/api)
"""
import os, sys, json, time, urllib.request, ssl

IMMICH_URL = os.environ.get("IMMICH_URL", "https://photos.mykk.us/api").rstrip("/")
API_KEY    = os.environ.get("IMMICH_API_KEY")
if not API_KEY:
    print("Set IMMICH_API_KEY first (export IMMICH_API_KEY=...)")
    sys.exit(2)

CTX = ssl.create_default_context()

def http_post_json(url_path, payload):
    url = f"{IMMICH_URL}{url_path}"
    req = urllib.request.Request(url, method="POST")
    req.add_header("x-api-key", API_KEY)
    req.add_header("Accept", "application/json")
    req.add_header("Content-Type", "application/json")
    data = json.dumps(payload).encode("utf-8")
    for _ in range(3):
        try:
            with urllib.request.urlopen(req, data=data, context=CTX, timeout=60) as r:
                _ = r.read()  # body is not needed for this endpoint
                return
        except Exception:
            time.sleep(0.2)
    raise SystemExit(f"Failed POST {url_path}")

def build_indexes(dump_path):
    with open(dump_path, "r", encoding="utf-8") as f:
        albums = json.load(f)

    # album name -> album id
    album_id_by_name = {}
    # lower(originalFileName) -> list of asset ids
    ids_by_name = {}

    for a in albums:
        aname = a.get("name") or a.get("albumName")
        aid   = a.get("id")
        if aname and aid:
            album_id_by_name[aname] = aid
        # assets might be in .assets
        for asset in (a.get("assets") or []):
            if not isinstance(asset, dict):  # tolerate weird shapes
                continue
            ofn = (asset.get("originalFileName") or asset.get("fileName") or "").strip()
            aid2 = asset.get("id")
            if ofn and aid2:
                key = ofn.lower()
                ids_by_name.setdefault(key, []).append(aid2)

    return album_id_by_name, ids_by_name

def extend_matches(ids_by_name, fname):
    """find asset id(s) for a filename; try exact, extension twins, and basename fallback"""
    want = fname.lower()
    if want in ids_by_name:
        return [ids_by_name[want][0]]

    # extension twins
    if "." in want:
        root, ext = want.rsplit(".", 1)
        for alt in ("jpg","jpeg","heic","png"):
            if alt == ext:
                continue
            alt_name = f"{root}.{alt}"
            if alt_name in ids_by_name:
                return [ids_by_name[alt_name][0]]

        # basename-only startswith (e.g., name.JPG vs name.jpg)
        for k in ids_by_name.keys():
            if k.startswith(root + "."):
                return [ids_by_name[k][0]]

    return []

def add_to_album(album_id, asset_ids):
    if not asset_ids:
        return 0
    B = 50
    added = 0
    for i in range(0, len(asset_ids), B):
        chunk = asset_ids[i:i+B]
        http_post_json(f"/albums/{album_id}/assets", {"assetIds": chunk})
        added += len(chunk)
        time.sleep(0.05)
    return added

def main():
    if len(sys.argv) != 4:
        print("Usage: python3 add_missing_from_dump.py immich_albums_detailed.json '<Album Name>' album_diffs/<...__missing.txt>")
        sys.exit(2)

    dump_path, album_name, missing_list = sys.argv[1], sys.argv[2], sys.argv[3]
    album_id_by_name, ids_by_name = build_indexes(dump_path)

    if album_name not in album_id_by_name:
        raise SystemExit(f"Album not found in dump: {album_name}")
    album_id = album_id_by_name[album_name]

    with open(missing_list, "r", encoding="utf-8") as f:
        names = [ln.strip() for ln in f if ln.strip()]

    to_add, not_found = [], []
    for i, fname in enumerate(names, 1):
        ids = extend_matches(ids_by_name, fname)
        if ids:
            to_add.append(ids[0])
        else:
            not_found.append(fname)
        if i % 25 == 0:
            print(f" checked {i}/{len(names)}…")

    added = add_to_album(album_id, to_add)
    print(f"{album_name}: added {added} | not found by name: {len(not_found)}")

    if not_found:
        nf = f"{album_name.replace('/','_')}__not_found_from_dump.txt"
        with open(nf, "w", encoding="utf-8") as o:
            o.write("\n".join(not_found))
        print(f"Wrote list: {nf}")

if __name__ == "__main__":
    main()

