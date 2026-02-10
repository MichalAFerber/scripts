# rename_s06_to_s00.py
#!/usr/bin/env python3
import argparse, re
from pathlib import Path

def main():
    ap = argparse.ArgumentParser(description="Turn S06E## in Season 00 filenames into next S00E##.")
    ap.add_argument("--root", required=True, help='Path to the series root (contains "Season 00")')
    ap.add_argument("--apply", action="store_true", help="Perform the renames")
    args = ap.parse_args()

    s00 = Path(args.root) / "Season 00"
    if not s00.is_dir():
        print(f'ERROR: "{s00}" not found')
        return

    # Find current max S00E##
    max_s00 = 0
    for p in s00.glob("*S00E*"):
        m = re.search(r"S00E(\d{2})", p.name, flags=re.I)
        if m:
            max_s00 = max(max_s00, int(m.group(1)))
    next_num = max_s00 + 1

    # Rename any S06E## files
    s06_files = sorted(s00.glob("*S06E*"))
    if not s06_files:
        print("No S06E## files found in Season 00.")
    for src in s06_files:
        new_tag = f"S00E{next_num:02d}"
        dst_name = re.sub(r"S06E\d{2}", new_tag, src.name, flags=re.I)
        dst = src.with_name(dst_name)

        print(f"{src.name}  ->  {dst.name}")
        if args.apply:
            if dst.exists():
                # resolve collisions
                base, ext = dst.stem, dst.suffix
                n = 1
                while dst.exists():
                    dst = src.with_name(f"{base} ({n}){ext}")
                    n += 1
            src.rename(dst)
        next_num += 1

    print("Mode:", "APPLY" if args.apply else "DRY-RUN")

if __name__ == "__main__":
    main()
