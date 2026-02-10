# save as: apply_official_titles_wwpv.py
# usage (dry run):
#   python3 apply_official_titles_wwpv.py --root "/path/to/wwpv"
# usage (apply):
#   python3 apply_official_titles_wwpv.py --root "/path/to/wwpv" --apply
#
# Only touches Season 05. Safe if run multiple times.

import argparse, os, re, sys

SERIES = "World's Wildest Police Videos"

S5_TITLES = {
    1:  "Car Bombs",
    2:  "Prison Assault",
    3:  "Stolen Sports Car",
    4:  "Armed Assailant",
    5:  "Detroit Car Chase",
    6:  "Courthouse Brawl",
    7:  "Fast and the Furious",
    8:  "Gunfire at Police Precinct",
    9:  "Stolen School Bus",
    10: "Grand Theft Forklift",
    11: "Assassin Pursuit",
    12: "Stolen Police SUV",
    13: "Trailer Park Showdown",
}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True, help="Path that contains Season 05 folder")
    ap.add_argument("--apply", action="store_true", help="Actually rename files")
    args = ap.parse_args()

    season_dir = os.path.join(args.root, "Season 05")
    if not os.path.isdir(season_dir):
        print(f"ERROR: {season_dir} not found", file=sys.stderr)
        sys.exit(1)

    print(f"Scanning: {season_dir}")
    changed = 0

    rx = re.compile(rf"^{re.escape(SERIES)}\s*-\s*S05E(\d{{2}})\b.*\.(mp4|mkv|mov|avi)$", re.IGNORECASE)

    for name in sorted(os.listdir(season_dir)):
        if name.startswith("."):
            continue
        m = rx.match(name)
        if not m:
            continue
        ep = int(m.group(1))
        ext = m.group(2)
        title = S5_TITLES.get(ep)
        if not title:
            print(f"  SKIP (no mapping for E{ep:02d}): {name}")
            continue

        new_name = f"{SERIES} - S05E{ep:02d} - {title}.{ext}"
        if name == new_name:
            continue

        src = os.path.join(season_dir, name)
        dst = os.path.join(season_dir, new_name)
        print(f"  RENAME: {name}\n       -> {new_name}\n")
        changed += 1
        if args.apply:
            if os.path.exists(dst):
                print(f"     ! Target exists, skipping: {dst}", file=sys.stderr)
            else:
                os.rename(src, dst)

    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"Done. Mode={mode}. Files changed={changed}.")

if __name__ == "__main__":
    main()
