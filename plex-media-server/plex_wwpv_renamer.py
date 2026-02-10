#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WWPV → Plex renamer (v2)

✓ Detects:  SxxEyy, S xx E yy, (S5 E6), 2x05 / 2 × 05 / 2 x 5, Season 4, Episode 5
✓ Cleans titles (removes stray " - - ", trims separators)
✓ Normalizes episode numbers to 2-digits
✓ Moves episodes into Season XX; compilations/spin-offs to Season 00
✓ Optional --assume-season N for names that only have "Episode 6" without a season
✓ Dry-run by default; use --apply to actually move/rename
✓ --csv writes an audit map (old_path,new_path)

Usage (dry-run first):
  python3 plex_wwpv_renamer_v2.py --src "/path/to/folder" \
    --dest "/Volumes/G-DRIVE 12TB/World's Wildest Police Videos"

Example: fix Season 00 drop-ins (like the list you posted):
  python3 plex_wwpv_renamer_v2.py \
    --src "/Volumes/G-DRIVE 12TB/World's Wildest Police Videos/Season 00" \
    --dest "/Volumes/G-DRIVE 12TB/World's Wildest Police Videos"

If some files only say "Episode 6" with no season, add (for that pass only):
  --assume-season 1
"""
import argparse, csv, re, sys
from pathlib import Path
from typing import Optional, Tuple

SERIES_NAME = "World's Wildest Police Videos"
EXTS = (".mp4", ".mkv", ".mov", ".avi")

# --- Patterns (robust) ---
RE_SE           = re.compile(r"[sS]\s*(\d{1,2})\s*[eE]\s*(\d{1,3})")              # S04E18, S 04 E 018, (S5 E6)
RE_X            = re.compile(r"(?<!\d)(\d{1,2})\s*[xX×]\s*(\d{1,2})(?!\d)")        # 2x05, 2 × 05, 2 x 5
RE_SEASON_EP    = re.compile(r"[Ss]eason\s*(\d{1,2})\s*(?:,?\s*|[-–—]?\s*)[Ee]pisode\s*(\d{1,3})")
RE_EP_ONLY      = re.compile(r"(?<!\w)[Ee]p(?:isode)?\s*0*(\d{1,3})(?!\w)")
RE_SERIES_ANY   = re.compile(r"world'?s\s+wildest\s+police\s+videos", re.IGNORECASE)

SPECIAL_HINTS = [  # keep these in Season 00 (compilations/spin-offs)
    "world's craziest police chases",
    "world's fastest police chases",
    "world's scariest police chases",
    "world's scariest police stings",
    "world's worst drivers",
    "most dangerous chases",
    "most dangerous crashes",
    "amazing police chases",
    "world's most dangerous police chases",
    "car crashes",
    "code red",
    "moment of survival",
    "surviving the moment of impact",
    "special forces",
    "riots",
]

def normalize(text: str) -> str:
    # full-width punctuation → ascii; tidy hyphens/spaces; squash " - - " runs
    repl = {"：": ":", "｜": " - ", "？": "?", "【": "", "】": ""}
    for k, v in repl.items(): text = text.replace(k, v)
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"\s*-\s*", " - ", text)
    text = re.sub(r"(?:\s*-\s*){2,}", " - ", text)   # collapse " - - "
    return text.strip()

def parse_se_ep(stem: str, assume_season: Optional[int]) -> Tuple[Optional[int], Optional[int]]:
    # 1) Prefer explicit "Season N, Episode M" (last occurrence wins)
    matches = list(RE_SEASON_EP.finditer(stem))
    if matches:
        m = matches[-1]
        return int(m.group(1)), int(m.group(2))

    # 2) SxxEyy (choose the last match with season > 0 if available)
    ses = list(RE_SE.finditer(stem))
    if ses:
        for m in reversed(ses):
            if int(m.group(1)) > 0:
                return int(m.group(1)), int(m.group(2))
        # otherwise fall back to the last SxxEyy match (might be S00E##)
        m = ses[-1]
        return int(m.group(1)), int(m.group(2))

    # 3) 2xYY (last occurrence)
    xs = list(RE_X.finditer(stem))
    if xs:
        m = xs[-1]
        return int(m.group(1)), int(m.group(2))

    # 4) Episode-only (if user provides --assume-season)
    if assume_season is not None:
        m = RE_EP_ONLY.search(stem)
        if m:
            return int(assume_season), int(m.group(1))

    return None, None

def related_to_show(stem_lower: str) -> bool:
    if "world's wildest police videos" in stem_lower: return True
    for hint in SPECIAL_HINTS:
        if hint in stem_lower: return True
    return False

def extract_title(stem: str) -> str:
    s = stem
    s = RE_SERIES_ANY.sub("", s)      # drop series name
    s = RE_SE.sub("", s)              # remove SxxEyy tokens
    s = RE_X.sub(" ", s)              # remove 2xYY tokens
    s = RE_SEASON_EP.sub("", s)       # remove "Season N, Episode M"
    s = RE_EP_ONLY.sub("", s)         # remove lone "Episode M"

    # tidy separators and empty parens
    s = re.sub(r"\(\s*\)", "", s)             # remove empty ()
    s = re.sub(r"(?:\s*-\s*){2,}", " - ", s)  # collapse " - - " runs
    s = re.sub(r"^\s*[-–—:]\s*", "", s)       # strip leading dash/colon
    s = re.sub(r"\s*[-–—:]\s*$", "", s)       # strip trailing dash/colon
    s = re.sub(r"\s+", " ", s).strip()
    return s

def unique_target(p: Path) -> Path:
    if not p.exists(): return p
    base, ext = p.stem, p.suffix
    i = 1
    while True:
        cand = p.with_name(f"{base} _dup{i}{ext}")
        if not cand.exists(): return cand
        i += 1

def next_special_counter(season00: Path) -> int:
    mx = 0
    if season00.exists():
        for f in season00.glob(f"{SERIES_NAME} - S00E*.?*"):
            m = re.search(r"S00E(\d{1,2})", f.name)
            if m:
                try:
                    mx = max(mx, int(m.group(1)))
                except: pass
    return mx

def plan_for_file(src: Path, dest_root: Path, assume_season: Optional[int], special_state: dict):
    stem_raw = src.stem
    norm = normalize(stem_raw)
    season, episode = parse_se_ep(norm, assume_season)
    title = extract_title(norm)
    ext = src.suffix

    if season is not None and episode is not None:
        s2, e2 = f"{season:02d}", f"{episode:02d}"
        season_dir = dest_root / f"Season {s2}"
        newname = f"{SERIES_NAME} - S{s2}E{e2}" + (f" - {title}" if title else "") + ext
        return src, season_dir / newname, "EPISODE"

    # specials
    if related_to_show(norm.lower()):
        s00 = dest_root / "Season 00"
        if "next_special" not in special_state:
            special_state["next_special"] = next_special_counter(s00) + 1
        idx = special_state["next_special"]; special_state["next_special"] = idx + 1
        epnum = f"{idx:02d}"
        t = title or f"Special {epnum}"
        newname = f"{SERIES_NAME} - S00E{epnum} - {t}{ext}"
        return src, s00 / newname, "SPECIAL"

    return None

def main():
    ap = argparse.ArgumentParser(description="Rename WWPV files into Plex format with robust pattern detection.")
    ap.add_argument("--src", required=True, help="Folder to scan (recursively)")
    ap.add_argument("--dest", required=True, help="Series root (Season XX folders will be created here)")
    ap.add_argument("--apply", action="store_true", help="Actually move/rename (default: dry-run)")
    ap.add_argument("--csv", help="Write CSV mapping of old_path,new_path")
    ap.add_argument("--assume-season", type=int, help="Assume this season number when only 'Episode N' is present")
    args = ap.parse_args()

    src_dir = Path(args.src).expanduser()
    dest_root = Path(args.dest).expanduser()
    if not src_dir.is_dir():
        print(f"ERROR: Source does not exist: {src_dir}", file=sys.stderr); sys.exit(1)
    print(f"Source: {src_dir}")
    print(f"Dest:   {dest_root}")
    print(f"Mode:   {'APPLY' if args.apply else 'DRY-RUN'}")
    if args.assume_season is not None:
        print(f"Assume-season for 'Episode N' only: {args.assume_season}")
    print()

    if args.apply: dest_root.mkdir(parents=True, exist_ok=True)

    specials_state = {}
    plans = []
    for ext in EXTS:
        for src in src_dir.rglob(f"*{ext}"):
            if not src.is_file(): continue
            plan = plan_for_file(src, dest_root, args.assume_season, specials_state)
            if not plan:
                print(f"SKIP: {src.name}\n"); continue
            old, dst, kind = plan
            dst_final = unique_target(dst)
            print(f"{kind}: {old.name}\n  -> {dst_final}\n")
            if args.apply:
                dst_final.parent.mkdir(parents=True, exist_ok=True)
                old.rename(dst_final)
            plans.append((str(old), str(dst_final)))

    if args.csv and plans:
        csv_path = Path(args.csv).expanduser()
        with csv_path.open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f); w.writerow(["old_path", "new_path"]); w.writerows(plans)
        print(f"Wrote CSV: {csv_path}")

    print("Done.", "Renamed/moved files." if args.apply else "No changes (dry-run). Use --apply to execute.")

if __name__ == "__main__":
    main()
