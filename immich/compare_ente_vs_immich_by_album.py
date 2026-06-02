#!/usr/bin/env python3
import argparse
import csv
import json
import os
import pathlib
import re
import sys
from typing import Dict, List, Set, Tuple


# --- Timestamp extraction helpers for loose matching ---
_TS_PATTERNS = [
    # 2015-10-15 10.01.56 / 2015-10-15 10-01-56 / 2015_10_15 10_01_56 etc.
    re.compile(r'(?i)(20\d{2})[^\d]?(\d{2})[^\d]?(\d{2})[ _T\-\.](\d{2})[^\d]?(\d{2})[^\d]?(\d{2})'),
    # 20151015_100156 or 20151015100156
    re.compile(r'(?i)\b(20\d{2})(\d{2})(\d{2})[_\-]?(\d{2})(\d{2})(\d{2})\b'),
]

def _extract_ts_digits_from_text(text: str):
    out = []
    s = str(text) if text is not None else ""
    for pat in _TS_PATTERNS:
        for m in pat.finditer(s):
            y, M, d, h, m_, sec = m.groups()
            out.append(f"{y}{M}{d}{h}{m_}{sec}")
    return out

def _extract_ts_digits_from_iso(dt: str):
    if not dt:
        return []
    m = re.search(r'(20\d{2})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})', dt)
    if not m:
        return []
    y, M, d, h, m_, s = m.groups()
    return [f"{y}{M}{d}{h}{m_}{s}"]
# -----------------------------
# Helpers
# -----------------------------

ALLOWED_EXTS = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".gif", ".bmp", ".tif", ".tiff", ".webp", ".mp4", ".mov", ".m4v", ".avi", ".mkv", ".webm", ".3gp"}

def _write_explain(path, album, strict_miss, immich_set, immich_keys, limit=12):
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write(f"Album: {album}\n")
            f.write(f"Immich items: {len(immich_set)}\n")
            f.write(f"Strict misses (showing up to {limit}): {len(strict_miss)}\n\n")
            # show a small random-ish sample of Immich keys for context
            sample_immich_keys = list(immich_keys)[:200]
            f.write(f"Immich key sample size: {len(sample_immich_keys)}\n\n")

            for i, fn in enumerate(strict_miss[:limit], 1):
                keys = sorted(_keys_for_filename(fn))
                hit = any(k in immich_keys for k in keys)
                f.write(f"{i:02d}. {fn}\n")
                f.write(f"    keys: {', '.join(keys)}\n")
                f.write(f"    intersects Immich? {'YES' if hit else 'NO'}\n\n")
    except Exception as e:
        # best-effort only
        pass

def norm_basename(fn: str) -> str:
    """Case-insensitive basename (lowercased)."""
    return pathlib.Path(fn).name.lower()

def stem_key(fn: str) -> str:
    """
    Loose key for filename matching:
    - lowercase
    - drop the extension
    - strip common duplicate suffixes like ' (1)', '(2)', '_1', '-1'
    - remove all punctuation/whitespace/underscores
    Result: only [a-z0-9] remain.
    """
    p = pathlib.Path(fn)
    stem = p.stem.lower()

    # Strip common duplicate suffixes repeatedly (e.g., "scan_2024(1)_1-1")
    # matches: " (123)", "(2)", "_2", "-3"
    dup_suffix = re.compile(r'(?:[\s\-_]*(?:\(\d+\)|\[\d+\]|-\d+|_\d+))+$')
    stem = dup_suffix.sub('', stem)

    # Remove everything that isn't a-z or 0-9
    stem = re.sub(r'[^a-z0-9]', '', stem)
    return stem

# --- SMART LOOSE MATCH HELPERS (safe version) ---
# Generate multiple keys but DO NOT over-strip natural words.

# Only remove a prefix if it appears as a token followed by a separator or digits.
# e.g. "img-123", "scan_2024", "photo 0001" — but NOT "photobooth", "imagination".
_LOOSE_PREFIX_RE = re.compile(
    r'^(?:img|dsc|pxl|scan|scanned|photo|picture)(?:[\s\-_]*|\d+)(.*)$',
    flags=re.IGNORECASE,
)

def _lower_no_ext(fn: str) -> str:
    return pathlib.Path(fn).stem.lower()

def _strip_edited(stem: str) -> str:
    """
    Remove common non-semantic suffixes that appear after edits/exports.
    Safe: only affects trailing tokens.
    """
    s = stem
    # e.g. "name - edited", "name (edited)", "name_edited", repeated variants
    s = re.sub(r'(?i)[\s\-_]*(?:\(|\[)?edited(?:\)|\])?$', '', s)
    s = re.sub(r'(?i)(?:[\s\-_]*(?:\(|\[)?edited(?:\)|\]))+$', '', s)
    # e.g. trailing " - copy", "_copy", "(copy)"
    s = re.sub(r'(?i)[\s\-_]*(?:\(|\[)?copy(?:\)|\])?$', '', s)
    # e.g. simple version tails: _v2, -v3
    s = re.sub(r'(?i)[\s\-_]*v\d+$', '', s)
    # e.g. trailing duplicate counters: _1, -2, (3)
    s = re.sub(r'(?:[\s\-_]*(?:\(\d+\)|\[\d+\]|-\d+|_\d+))+$', '', s)
    return s.strip()

def _only_alnum(s: str) -> str:
    return re.sub(r'[^a-z0-9]', '', s)

def _only_digits(s: str) -> str:
    return re.sub(r'[^0-9]', '', s)

def _maybe_drop_prefix(stem: str) -> str:
    m = _LOOSE_PREFIX_RE.match(stem)
    return m.group(1) if m else stem

def _keys_for_stem(stem: str) -> set[str]:
    """Build keys from a given stem (no extension)."""
    k = set()
    s0 = stem
    s1 = _strip_edited(s0)
    s2 = _maybe_drop_prefix(s1)

    for s in (s0, s1, s2):
        if not s:
            continue
        a = _only_alnum(s)
        d = _only_digits(s)
        if a:
            k.add(a)
            # also "edited" permutations for this variant
            k.add(_only_alnum(s + "-edited"))
            k.add(_only_alnum(s + "-edited-edited"))
        if d:
            k.add(d)
            for n in (10, 12, 14):  # short digit tails for timestamps
                if len(d) >= n:
                    k.add(d[-n:])

    # last resort: if everything got stripped, fall back to original stem
    if not k and s0:
        k.add(_only_alnum(s0))
    return k

def _keys_for_filename(fn: str) -> set[str]:
    """
    Keys derived from the filename (no extension), including any timestamp patterns.
    """
    ks = _keys_for_stem(_lower_no_ext(fn))
    for ts in _extract_ts_digits_from_text(fn):
        ks.add(ts)
    return ks

def write_csv(out_path: str, rows: List[List], header: List[str]) -> None:
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)

def read_album_map(map_path: str) -> Dict[str, str]:
    amap: Dict[str, str] = {}
    if not map_path or not os.path.isfile(map_path):
        return amap
    with open(map_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = [p.strip() for p in line.split(",")]
            if len(parts) >= 2 and parts[0]:
                amap[parts[0]] = parts[1] or parts[0]
    return amap

def read_skip_list(skip_path: str) -> Set[str]:
    s: Set[str] = set()
    if not skip_path or not os.path.isfile(skip_path):
        return s
    with open(skip_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                s.add(line)
    return s

# -----------------------------
# Loaders
# -----------------------------

def scan_albums_from_root(root: str) -> Dict[str, Set[str]]:
    """
    Treat each immediate subfolder of `root` as an album.
    Collect case-insensitive basenames for ALLOWED_EXTS.
    """
    albums: Dict[str, Set[str]] = {}
    rootp = pathlib.Path(root)
    if not rootp.is_dir():
        return albums

    for child in sorted([p for p in rootp.iterdir() if p.is_dir()]):
        album_name = child.name
        files: Set[str] = set()
        for fp in child.rglob("*"):
            if fp.is_file() and fp.suffix.lower() in ALLOWED_EXTS:
                files.add(norm_basename(fp.name))
        albums[album_name] = files
    return albums

def load_ente(ente_json_path: str) -> Dict[str, Set[str]]:
    """
    We key off the *folder* layout near export_status.json.
    Even if the JSON shape varies, the folders are authoritative.
    """
    if not ente_json_path:
        return {}
    root = pathlib.Path(ente_json_path).resolve().parent
    return scan_albums_from_root(str(root))

def load_immich(immich_json_path: str) -> Dict[str, Set[str]]:
    """
    Expect JSON like: [{ "name": "Album", "assets": [ { "originalFileName": "foo.jpg" }, ... ] }, ...]
    Build per-album set of lowercased basenames.
    """
    with open(immich_json_path, encoding="utf-8") as f:
        data = json.load(f)

    albums: Dict[str, Set[str]] = {}
    for a in data:
        name = a.get("name", "")
        aset = set()
        for asset in a.get("assets", []) or []:
            fn = asset.get("originalFileName") or ""
            if fn:
                aset.add(norm_basename(fn))
        if name:
            albums[name] = aset
    return albums


def load_immich_keys(immich_json_path: str) -> Dict[str, Set[str]]:
    """
    Build per-album *key sets* for loose comparison:
      - filename-derived keys (alnum, edited-variants, digit-only tails, timestamps in name)
      - 14-digit timestamps from fileCreatedAt and exifInfo.dateTimeOriginal (if present)
    """
    with open(immich_json_path, encoding="utf-8") as f:
        data = json.load(f)
    albums: Dict[str, Set[str]] = {}
    for a in data:
        name = a.get("name", "")
        kset: Set[str] = set()
        for asset in a.get("assets", []) or []:
            fn = (asset.get("originalFileName") or "").strip()
            if fn:
                kset.update(_keys_for_filename(fn))
            created = (asset.get("fileCreatedAt") or "").strip()
            if created:
                for ts in _extract_ts_digits_from_iso(created):
                    kset.add(ts)
            exif = asset.get("exifInfo") or {}
            dto = (exif.get("dateTimeOriginal") or "").strip()
            if dto:
                for ts in _extract_ts_digits_from_text(dto):
                    kset.add(ts)
                for ts in _extract_ts_digits_from_iso(dto):
                    kset.add(ts)
        if name:
            albums[name] = kset
    return albums
# -----------------------------
# Comparison
# -----------------------------

def compare_albums(
    ente_albums: Dict[str, Set[str]],
    immich_albums: Dict[str, Set[str]],
    amap: Dict[str, str],
    skip_ente: Set[str],
    diff_dir: str,
    loose: bool,
    immich_keys_by_album: Dict[str, Set[str]] | None = None
) -> Tuple[List[List], int, int, int, int]:
    """
    Returns (rows, checked, ok, missing_count, notfound)
    """
    os.makedirs(diff_dir, exist_ok=True)

    rows: List[List] = []
    ok = 0
    missing_count = 0
    notfound = 0
    checked = 0

    for ente_name in sorted(ente_albums.keys()):
        if ente_name in skip_ente:
            continue

        ente_files = ente_albums[ente_name]
        immich_name = amap.get(ente_name, ente_name)
        immich_set = immich_albums.get(immich_name)

        if immich_set is None:
            status = "ALBUM MISSING"
            rows.append([ente_name, immich_name, len(ente_files), 0, len(ente_files), status])
            notfound += 1
            checked += 1
            # write missing = all files
            miss_path = os.path.join(diff_dir, f"{ente_name}__VS__{immich_name}__missing.txt")
            with open(miss_path, "w", encoding="utf-8") as f:
                for fn in sorted(ente_files):
                    f.write(fn + "\n")
            continue

        # --- strict first ---
        # --- strict first ---
        strict_miss = sorted(ente_files - immich_set)

        if not loose:
            miss = strict_miss
        else:
            # Build Immich keyset (prefer precomputed with timestamps)
            if immich_keys_by_album is not None:
                immich_keys = set(immich_keys_by_album.get(immich_name, set()))
            else:
                immich_keys = set()
                for x in immich_set:
                    immich_keys.update(_keys_for_filename(x))

            # Optional explain mode via env var
            EXPLAIN = os.environ.get("COMPARE_EXPLAIN", "").lower() in ("1", "true", "yes", "on")
            explain_path = os.path.join(
                diff_dir, f"{ente_name}__VS__{immich_name}__EXPLAIN.txt"
            ) if EXPLAIN else None

            # Only try to "recover" strict misses with loose keys.
            # This guarantees loose can only reduce, never increase, misses.
            miss = []
            for x in strict_miss:
                if _keys_for_filename(x).isdisjoint(immich_keys):
                    miss.append(x)

            if EXPLAIN and strict_miss:
                _write_explain(explain_path, f"{ente_name} → {immich_name}",
                               strict_miss, immich_set, immich_keys)

        status = "OK" if not miss else "MISSING"
        if status == "OK":
            ok += 1
        else:
            missing_count += 1

        rows.append([ente_name, immich_name, len(ente_files), len(immich_set), len(miss), status])

        if miss:
            miss_path = os.path.join(diff_dir, f"{ente_name}__VS__{immich_name}__missing.txt")
            with open(miss_path, "w", encoding="utf-8") as f:
                for fn in miss:
                    f.write(fn + "\n")

        checked += 1

    return rows, checked, ok, missing_count, notfound

# -----------------------------
# Main
# -----------------------------

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Compare Ente export (by folders) → Immich albums (one-way)."
    )
    p.add_argument("--ente", required=True, help="Path to Ente export_status.json (we scan its parent folder).")
    p.add_argument("--immich", required=True, help="Path to immich_albums_detailed.json")
    p.add_argument("--map", default="", help="Optional album_map.csv (ente,immich)")
    p.add_argument("--skip-ente", default="", help="Optional skip_ente.txt (one album per line)")
    p.add_argument("--out", default="album_comparison.csv", help="Output CSV path")
    p.add_argument("--diff-dir", default="album_diffs", help="Where to write *_missing.txt lists")
    p.add_argument("--loose", action="store_true", help="Loose compare (stem-only, ignore punctuation/extension)")
    return p.parse_args()

def main() -> None:
    args = parse_args()

    # Allow env override for loose mode
    if not args.loose and os.environ.get("COMPARE_LOOSE", "").lower() in ("1", "true", "yes", "on"):
        args.loose = True

    # Build Ente album sets by scanning the folder that contains export_status.json
    ente_albums = load_ente(args.ente)
    if not ente_albums:
        print(f"[warn] Could not read Ente albums via folders near: {args.ente}", file=sys.stderr)

    # Load Immich album sets
    immich_albums = load_immich(args.immich)

    # Optional mappings and skips
    amap = read_album_map(args.map)
    skip_ente = read_skip_list(args.skip_ente)

    # Compare
    immich_keys_by_album = load_immich_keys(args.immich) if args.loose else None

    rows, checked, ok, missing_count, notfound = compare_albums(
        ente_albums, immich_albums, amap, skip_ente, args.diff_dir, args.loose, immich_keys_by_album
    )

    # Write CSV
    write_csv(args.out, rows, ["ente_album", "immich_album", "ente_items", "immich_items", "missing", "status"])

    # Summary
    print(f"Wrote {args.out}")
    print(f"Ente albums checked: {checked}")
    print(f"Albums OK: {ok} | Albums with missing items: {missing_count} | Albums not found in Immich: {notfound}")
    print(f"Per-album missing lists (if any): {args.diff_dir}/")

if __name__ == "__main__":
    main()
