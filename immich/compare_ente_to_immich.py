#!/usr/bin/env python3
import os, json, csv, argparse
from collections import defaultdict

def load_ente(path):
    j = json.load(open(path))
    coll_names = j.get("collectionExportNames", {})
    file_map = j.get("fileExportNames", {})  # compositeKey -> filename
    # Build album -> set(filenames)
    album_files = defaultdict(set)
    for composite, fname in file_map.items():
        parts = str(composite).split("_")
        coll_id = parts[1] if len(parts) >= 2 else "UNKNOWN"
        album = coll_names.get(coll_id, f"UNKNOWN:{coll_id}")
        album_files[album].add(os.path.basename(fname).lower())
    return album_files

def load_immich(path):
    j = json.load(open(path))
    # Build album -> set(filenames)
    album_files = defaultdict(set)
    for a in j:
        name = a.get("name") or f"UNNAMED:{a.get('id')}"
        for x in a.get("assets", []):
            fn = (x.get("originalFileName") or "").lower()
            if fn:
                album_files[name].add(os.path.basename(fn))
    return album_files

def load_mapping(path):
    mapping = {}
    if not path: return mapping
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            mapping[row["ente_album"]] = row["immich_album"]
    return mapping

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ente", default="export_status.json")
    ap.add_argument("--immich", default="immich_albums_detailed.json")
    ap.add_argument("--map", help="CSV with columns: ente_album,immich_album")
    ap.add_argument("--out", default="album_comparison.csv")
    args = ap.parse_args()

    ente = load_ente(args.ente)
    imm  = load_immich(args.immich)
    amap = load_mapping(args.map)

    # Align names via mapping (if provided)
    aligned = {}
    for e_album, files in ente.items():
        i_name = amap.get(e_album, e_album)  # default to same name
        aligned[e_album] = (i_name, files)

    rows = []
    missing_albums = []
    mismatches = 0
    matched = 0

    for e_album, (i_album, e_files) in aligned.items():
        i_files = imm.get(i_album)
        if i_files is None:
            missing_albums.append((e_album, len(e_files)))
            rows.append([e_album, i_album, len(e_files), 0, len(e_files), 0, "ALBUM MISSING"])
            continue
        # Compare per-file by filename (case-insensitive)
        missing_files = sorted(list(e_files - i_files))
        extra_files   = sorted(list(i_files - e_files))
        status = "OK" if not missing_files and not extra_files else "MISMATCH"
        if status == "OK":
            matched += 1
        else:
            mismatches += 1
        rows.append([
            e_album, i_album,
            len(e_files), len(i_files),
            len(missing_files), len(extra_files),
            status
        ])

    # Any Immich-only albums (not in Ente)
    extra_immich_albums = sorted([a for a in imm.keys() if a not in [amap.get(x, x) for x in ente.keys()]])

    with open(args.out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["ente_album","immich_album","ente_count","immich_count","missing_files","extra_files","status"])
        w.writerows(rows)

    print(f"Wrote {args.out}")
    print(f"Ente albums: {len(ente)} | Immich albums: {len(imm)}")
    print(f"Matched albums: {matched} | Mismatched: {mismatches} | Missing in Immich: {len(missing_albums)}")
    if extra_immich_albums:
        print(f"Extra Immich albums not in Ente: {len(extra_immich_albums)} (see below)")
        for n in extra_immich_albums[:20]:
            print("  -", n)

if __name__ == "__main__":
    main()
