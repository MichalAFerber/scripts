#!/usr/bin/env python3
import os, json, time, urllib.request, urllib.error

BASE = os.environ.get("IMMICH_URL", "https://photos.mykk.us/api")
API  = os.environ["IMMICH_API_KEY"]
HEAD = {"Content-Type":"application/json","Accept":"application/json","x-api-key":API}

def post(path, body):
    req = urllib.request.Request(f"{BASE}{path}", data=json.dumps(body).encode(), headers=HEAD, method="POST")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())

def try_page_size(ep):
    assets, page, size = [], 1, 1000
    while True:
        resp = post(ep, {"page": page, "size": size, "withExif": False})
        items = resp.get("assets") or resp.get("items") or []
        assets.extend(items)
        print(f"[{ep}] page {page}: +{len(items)} (total {len(assets)})")
        nxt = resp.get("nextPage")
        if not nxt or len(items) == 0:
            break
        page = int(nxt) if isinstance(nxt, int) or str(nxt).isdigit() else page + 1
        time.sleep(0.1)
    return assets

def try_skip_take(ep):
    assets, skip, take = [], 0, 1000
    while True:
        resp = post(ep, {"skip": skip, "take": take, "withExif": False})
        items = resp.get("assets") or resp.get("items") or (resp if isinstance(resp, list) else [])
        if not items:
            break
        assets.extend(items)
        skip += len(items)
        print(f"[{ep}] skip {skip-len(items)}: +{len(items)} (total {len(assets)})")
        time.sleep(0.1)
    return assets

def main():
    # Prefer /search/assets; fall back to /search/metadata (page/size first, then skip/take)
    tried = []
    for ep in ("/search/assets", "/search/metadata"):
        try:
            data = try_page_size(ep)
            if len(data) >= 50:  # looks good
                with open("immich_assets.json","w") as f: json.dump(data, f, indent=2)
                print(f"Wrote immich_assets.json with {len(data)} assets via {ep} (page/size)")
                return
            # If we only got a tiny page and no nextPage, try skip/take form:
            data2 = try_skip_take(ep)
            if data2:
                with open("immich_assets.json","w") as f: json.dump(data2, f, indent=2)
                print(f"Wrote immich_assets.json with {len(data2)} assets via {ep} (skip/take)")
                return
            tried.append(ep)
        except urllib.error.HTTPError as e:
            print(f"{ep} -> HTTP {e.code}")
            if e.code != 404: raise
            tried.append(ep)
        except Exception as e:
            print(f"{ep} -> {e}")
            tried.append(ep)

    raise SystemExit(f"Failed on endpoints {tried}. Check API key (needs asset.read) and reverse proxy.")

if __name__ == "__main__":
    main()

