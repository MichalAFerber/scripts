#!/usr/bin/env python3
"""
add_missing_by_filename_indexed.py - Add Missing Assets to Immich Album (live index)

Builds a live filename index by streaming ALL assets from Immich's /search/metadata
endpoint, then matches filenames from a missing-files list (with extension-twin
and basename fallbacks) and adds matches to the target album.

Unlike add_missing_from_dump.py, this does NOT require a pre-exported JSON dump --
it queries the Immich API directly, making it slower but always up-to-date.

Usage:
    export IMMICH_API_KEY="your-api-key"
    python3 add_missing_by_filename_indexed.py 'Album Name' album_diffs/missing.txt

Arguments:
    1. Target Immich album name
    2. Path to a missing-files text list (one filename per line)

Environment variables:
    IMMICH_API_KEY  (required) - Your Immich API key
    IMMICH_URL      (optional) - Immich API base URL (default: https://photos.mykk.us/api)
"""
import os, sys, json, time, urllib.request, urllib.error, ssl

IMMICH_URL = os.environ.get("IMMICH_URL", "https://photos.mykk.us/api").rstrip("/")
API_KEY    = os.environ.get("IMMICH_API_KEY")
if not API_KEY:
    print("Set IMMICH_API_KEY first (export IMMICH_API_KEY=...)")
    sys.exit(2)

CTX = ssl.create_default_context()

def api(path, method="GET", data=None, timeout=60, retries=3):
    url = f"{IMMICH_URL}{path}"
    req = urllib.request.Request(url, method=method)
    req.add_header("x-api-key", API_KEY)
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
        req.data = json.dumps(data).encode("utf-8")
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, context=CTX, timeout=timeout) as r:
                raw = r.read()
                if not raw:
                    return {}
                try:
                    return json.loads(raw.decode("utf-8"))
                except json.JSONDecodeError:
                    return {}
        except Exception as e:
            if attempt == retries - 1:
                raise
            time.sleep(0.4)

def safe_list(x):
    return x if isinstance(x, list) else []

def asset_from_any(x):
    # Handle dicts, nested dicts, or raw IDs
    if isinstance(x, dict):
        if x.get("id"):
            return x
        if isinstance(x.get("asset"), dict) and x["asset"].get("id"):
            return x["asset"]
    elif isinstance(x, str):
        # last resort, fetch by id
        try:
            return api(f"/assets/{x}")
        except:
            return {}
    return {}

def get_album_id_by_name(name):
    # First try simple list
    for a in safe_list(api("/albums")):
        if a.get("albumName") == name or a.get("name") == name:
            return a["id"]
    # Fallback via search/metadata (albums page)
    resp = api("/search/metadata", method="POST", data={"albums": {"take": 2000}})
    for a in safe_list(resp.get("albums")):
        if a.get("albumName") == name or a.get("name") == name:
            return a["id"]
    raise SystemExit(f"Album not found: {name}")

def iter_all_assets(batch=500):
    # Use /search/metadata pagination (no filters) to stream all assets
    skip = 0
    total = 0
    while True:
        payload = {"skip": skip, "take": batch}
        resp = api("/search/metadata", method="POST", data=payload)
        items = safe_list(resp.get("assets"))
        if not items:
            break
        for it in items:
            a = asset_from_any(it)
            if a:
                yield a
        got = len(items)
        total += got
        skip += got
        print(f"  indexed {total} assets...", flush=True)
        if got < batch:
            break

def build_name_index():
    # Map: lower(originalFileName) -> [assetId, ...]
    print("Building filename index from Immich…")
    idx = {}
    for a in iter_all_assets(batch=500):
        aid = a.get("id")
        ofn = a.get("originalFileName") or a.get("fileName") or ""
        if not aid or not ofn:
            continue
        key = ofn.lower()
        idx.setdefault(key, []).append(aid)
    print(f"Indexed {sum(len(v) for v in idx.values())} name entries "
          f"across {len(idx)} unique filenames.")
    return idx

def add_assets_to_album(album_id, asset_ids):
    if not asset_ids:
        return
    B = 50
    for i in range(0, len(asset_ids), B):
        chunk = asset_ids[i:i+B]
        api(f"/albums/{album_id}/assets", method="POST", data={"assetIds": chunk})
        time.sleep(0.05)

def twins_for(name):
    # generate extension twins
    if "." not in name:
        return [name]
    root, ext = name.rsplit(".", 1)
    alts = ["jpg","jpeg","heic","png","JPG","JPEG","HEIC","PNG"]
    out = [name]
    for a in alts:
        if a.lower() != ext.lower():
            out.append(f"{root}.{a}")
    return out

def run(album_name, missing_list_path):
    album_id = get_album_id_by_name(album_name)
    with open(missing_list_path, "r", encoding="utf-8") as f:
        names = [ln.strip() for ln in f if ln.strip()]
    idx = build_name_index()

    to_add = []
    not_found = []
    for i, fname in enumerate(names, 1):
        found_id = None
        # exact lower match
        key = fname.lower()
        if key in idx:
            found_id = idx[key][0]
        else:
            # try extension twins
            for alt in twins_for(fname):
                if alt.lower() in idx:
                    found_id = idx[alt.lower()][0]
                    break
            # try base name only (ignore ext) — choose first key that starts with base + "."
            if not found_id and "." in fname:
                base = fname.rsplit(".",1)[0].lower()
                # quick lookups
                for k in (k for k in idx.keys() if k.startswith(base + ".")):
                    found_id = idx[k][0]
                    break

        if found_id:
            to_add.append(found_id)
        else:
            not_found.append(fname)

        if i % 25 == 0:
            print(f" looked up {i}/{len(names)}…")

    if to_add:
        add_assets_to_album(album_id, to_add)

    print(f"{album_name}: added {len(to_add)} | not found by name: {len(not_found)}")
    if not_found:
        nf = f"{album_name.replace('/','_')}__not_found_after_index.txt"
        with open(nf, "w", encoding="utf-8") as o:
            o.write("\n".join(not_found))
        print(f"Wrote list: {nf}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 add_missing_by_filename_indexed.py '<Album Name>' album_diffs/<Ente>__VS__<Immich>__missing.txt")
        sys.exit(2)
    run(sys.argv[1], sys.argv[2])

