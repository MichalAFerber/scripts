# wwpv_specials_check_v2.py
#!/usr/bin/env python3
from pathlib import Path
import re, sys, unicodedata

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
s00 = root / "Season 00"

def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", " ", s)  # drop punctuation/symbols
    return " ".join(s.split())

official = [
    # World's Scariest Police Chases 1–6
    "World's Scariest Police Chases",
    "World's Scariest Police Chases 2",
    "World's Scariest Police Chases 3",
    "World's Scariest Police Chases 4",
    "World's Scariest Police Chases 5",
    "World's Scariest Police Chases 6",
    # Shootouts 1–2
    "World's Scariest Police Shootouts",
    "World's Scariest Police Shootouts 2",
    # Surviving the Moment of Impact 1–4
    "Surviving the Moment of Impact",
    "Surviving the Moment of Impact 2",
    "Surviving the Moment of Impact 3",
    "Surviving the Moment of Impact 4",
    # World's Worst Drivers 1–3
    "World's Worst Drivers: Caught on Tape",
    "World's Worst Drivers: Caught on Tape 2",
    "World's Worst Drivers: Caught on Tape 3",
    # Most Shocking Moments 1–3
    "World's Most Shocking Moments: Caught on Tape",
    "World's Most Shocking Moments: Caught on Tape 2",
    "World's Most Shocking Moments: Caught on Tape 3",
    # Misc
    "World's Scariest Police Stings",
    "Prisoners: Out Of Control",
    "Riots: Mobs Out Of Control",
    "Train Wrecks",
    "Getting a Ticket in America",
    "World's Most Dangerous Police Chases",
    "World's Fastest Police Chases",
    "World's Craziest Police Chases",
]

have = set()
if s00.exists():
    for f in s00.glob("*"):
        if f.is_file():
            have.add(norm(f.stem))

def present(name: str) -> bool:
    n = norm(name)
    # consider match if either contains the other (robust to extra words like "ManxBox")
    return any(n in h or h in n for h in have)

for name in official:
    print(("✓" if present(name) else "✗"), name)
