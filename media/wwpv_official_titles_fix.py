#!/usr/bin/env python3
import sys, re, argparse
from pathlib import Path
from shutil import move

series = "World's Wildest Police Videos"

# ---- Season 1 official titles (in order) ----
s01_titles = [
    "High Speed Car Chase",
    "Russian Mafia Footage",
    "California Riots",
    "Montana Car Chase",
    "Riot in Tahiti!",
    "Armed with a Sword!",
]

# Patterns we'll search for in filenames currently sitting in Season 00
s01_matchers = [
    re.compile(r"high\s*speed\s*car\s*chase", re.I),
    re.compile(r"russian\s*mafia", re.I),
    re.compile(r"california\s*riots?", re.I),
    re.compile(r"montana\s*car\s*chase", re.I),
    re.compile(r"riot\s*in\s*tahiti", re.I),
    re.compile(r"armed\s*with\s*a\s*sword", re.I),
]

# ---- Season 5 (2012) official titles by episode number ----
s05_titles = {
    1: "Episode 501 \u2013 One Bullet Away from Insanity",
    2: "Episode 502 \u2013 Between a Diamond and a Hard Place",
    3: "Episode 503 \u2013 Driving While Crazy",
    4: "Episode 504 \u2013 Sky High on Rage",
    5: "Episode 505 \u2013 Locking Horns with the Law",
    6: "Episode 506 \u2013 Roaring Into Hot Pursuit",
    7: "Episode 507 \u2013 Guns Speak Louder Than Words",
    8: "Episode 508 \u2013 Crookbook",
    9: "Episode 509 \u2013 Soft Targets Hard Lessons",
    10: "Episode 510 \u2013 Between the Crosshairs",
    11: "Episode 511 \u2013 Revenge of the K9s",
    12: "Episode 512 \u2013 Rebel Without a Clue",
    13: "Episode 513 \u2013 Thick as Thieves",
}

def ensure_dir(p: Path, apply: bool):
    if apply:
        p.mkdir(parents=True, exist_ok=True)

def rename(src: Path, dst: Path, apply: bool):
    if apply:
        ensure_dir(dst.parent, apply)
    if src.resolve() == dst.resolve():
        return
    if dst.exists():
        # Append (n) if needed
        base = dst.stem
        ext = dst.suffix
        n = 1
        while True:
            candidate = dst.with_name(f"{base} ({n}){ext}")
            if not candidate.exists():
                dst = candidate
                break
            n += 1
    if apply:
        print(f"RENAME:\n  {src}\n  -> {dst}\n")
        move(str(src), str(dst))
    else:
        print(f"[DRY RUN] Would rename:\n  {src}\n  -> {dst}\n")

def find_season_dir(root: Path, num: int) -> Path:
    return root / f"Season {num:02d}"

def main():
    parser = argparse.ArgumentParser(description="Fix WWPV official titles: move S01 episodes from Season 00, fix S03E05 title, retitle S05 episodes.")
    parser.add_argument("root", nargs="?", default=None, help="Series root folder (contains Season 00, Season 02, etc.). Defaults to current directory.")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be changed without making changes (default)")
    parser.add_argument("--apply", action="store_true", help="Actually move/rename files")
    args = parser.parse_args()

    root = Path(args.root) if args.root else Path.cwd()
    apply = args.apply

    print(f"Mode: {'APPLY' if apply else 'DRY-RUN'}")
    print(f"Root: {root}\n")

    # 0) If there is a folder incorrectly called "Season 06", move it to Season 00 (specials)
    s06 = find_season_dir(root, 6)
    if s06.exists():
        s00 = find_season_dir(root, 0)
        ensure_dir(s00, apply)
        for f in s06.glob("*"):
            dst = s00 / f.name
            rename(f, dst, apply)
        # Remove empty dir
        if apply:
            try:
                s06.rmdir()
            except OSError:
                pass

    # 1) Move the 6 Season 1 episodes out of Season 00 into Season 01 with correct numbering/titles
    s00 = find_season_dir(root, 0)
    s01 = find_season_dir(root, 1)
    ensure_dir(s01, apply)

    if s00.exists():
        files = sorted([p for p in s00.iterdir() if p.is_file()])
        # For each official S01 slot, look for a matching file by title pattern
        for idx, (title, pat) in enumerate(zip(s01_titles, s01_matchers), start=1):
            # skip if already there
            already = list(s01.glob(f"*S01E{idx:02d}*"))
            if already:
                continue
            # find candidate in Season 00
            cand = None
            for f in files:
                if pat.search(f.name):
                    cand = f
                    break
            if cand:
                new = s01 / f"{series} - S01E{idx:02d} - {title}{cand.suffix}"
                rename(cand, new, apply)

    # 2) Fix S03E05 hyphen to "High-Speed Chases"
    s03 = find_season_dir(root, 3)
    if s03.exists():
        for f in s03.glob("*S03E05*"):
            wanted = s03 / f"{series} - S03E05 - High-Speed Chases{f.suffix}"
            if wanted.name != f.name:
                rename(f, wanted, apply)

    # 3) Retitle S05 episodes to official names
    s05 = find_season_dir(root, 5)
    if s05.exists():
        for f in s05.glob("*S05E*"):
            m = re.search(r"S05E(\d{2})", f.name, re.I)
            if not m:
                continue
            ep = int(m.group(1))
            title = s05_titles.get(ep)
            if not title:
                continue
            new = s05 / f"{series} - S05E{ep:02d} - {title}{f.suffix}"
            if new.name != f.name:
                rename(f, new, apply)

    print("Done." + ("" if apply else " Run with --apply to execute changes."))

if __name__ == "__main__":
    main()
