#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Undo/restore moves made by plex_wwpv_renamer.py using its CSV map.

Usage:
  Dry-run:
    python3 undo_plex_wwpv_rename.py --csv "/path/to/rename_log.csv"
  Apply (actually move files):
    python3 undo_plex_wwpv_rename.py --csv "/path/to/rename_log.csv" --apply --log ~/Desktop/undo_log.csv

Notes:
- Expects a CSV with headers: old_path,new_path (as written by the renamer).
- If the destination already exists, appends " (restored N)" to avoid clobbering.
- Moves common sidecars with the same basename by default (.srt,.vtt,.nfo,.jpg,.jpeg,.png).
"""

import argparse
import csv
import shutil
import sys
from pathlib import Path

def unique_target(dst: Path) -> Path:
    if not dst.exists():
        return dst
    stem, suf, parent = dst.stem, dst.suffix, dst.parent
    n = 1
    while True:
        cand = parent / f"{stem} (restored {n}){suf}"
        if not cand.exists():
            return cand
        n += 1

def move_one(src: Path, dst: Path, apply: bool) -> Path:
    dst_final = unique_target(dst)
    if apply:
        dst_final.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), str(dst_final))
    return dst_final

def main():
    p = argparse.ArgumentParser(description="Undo renames/moves using the mapping CSV from plex_wwpv_renamer.py")
    p.add_argument("--csv", required=True, help="Path to CSV (old_path,new_path)")
    p.add_argument("--apply", action="store_true", help="Actually move files (default is dry-run)")
    p.add_argument("--sidecars", default=".srt,.vtt,.nfo,.jpg,.jpeg,.png", help="Comma-separated sidecar extensions")
    p.add_argument("--log", help="Write an undo log CSV (from_path,to_path)")
    p.add_argument("--force", action="store_true", help="Ignore rows where neither path exists")
    args = p.parse_args()

    csv_path = Path(args.csv).expanduser()
    if not csv_path.is_file():
        print(f"CSV not found: {csv_path}", file=sys.stderr)
        sys.exit(1)

    sidecars = []
    for e in (x.strip() for x in args.sidecars.split(",")):
        if not e:
            continue
        sidecars.append(e if e.startswith(".") else "." + e)

    print(f"CSV:    {csv_path}")
    print(f"Mode:   {'APPLY' if args.apply else 'DRY-RUN'}")
    print(f"Extras: sidecars={sidecars}")
    print()

    with csv_path.open(newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))

    start = 0
    if rows and rows[0] and len(rows[0]) >= 2 and (
        "old_path" in rows[0][0].lower() or "new_path" in rows[0][1].lower()
    ):
        start = 1

    planned = []
    issues = 0

    for i in range(start, len(rows)):
        row = rows[i]
        if len(row) < 2:
            continue
        old = Path(row[0]).expanduser()
        new = Path(row[1]).expanduser()

        # Decide direction: if new exists, we undo (new -> old). If only old exists, likely already undone.
        if new.exists():
            src, dst = new, old
        elif old.exists():
            print(f"ROW {i}: Already at original: {old.name} -- skipping")
            print()
            continue
        else:
            msg = f"ROW {i}: Neither exists:\n  {old}\n  {new}"
            if args.force:
                print(msg + "\n  --force: continuing\n")
                continue
            else:
                print(msg + "\n", file=sys.stderr)
                issues += 1
                continue

        print(f"UNDO: {src}")
        dst_final = move_one(src, dst, args.apply)
        print(f"  ->  {dst_final}")

        # Move sidecars (same stem)
        src_stem, dst_stem = src.with_suffix(""), dst_final.with_suffix("")
        for ext in sidecars:
            s_old, s_new = src_stem.with_suffix(ext), dst_stem.with_suffix(ext)
            if s_old.exists():
                s_new_final = unique_target(s_new)
                print(f"  sidecar: {s_old.name} -> {s_new_final.name}")
                if args.apply:
                    s_new_final.parent.mkdir(parents=True, exist_ok=True)
                    shutil.move(str(s_old), str(s_new_final))

        planned.append((str(src), str(dst_final)))
        print()

    if args.log and planned:
        log_path = Path(args.log).expanduser()
        with log_path.open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["from_path", "to_path"])
            w.writerows(planned)
        print(f"Wrote undo log: {log_path}")

    if issues:
        print(f"Completed with {issues} issue(s). Re-run with --force to ignore missing rows.")

    print("Done. " + ("Restored files." if args.apply else "Dry-run only. Add --apply to execute."))

if __name__ == "__main__":
    main()
