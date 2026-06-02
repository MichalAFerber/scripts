#!/usr/bin/env bash
#
# add_music.sh — Organize, verify, and deduplicate a music library.
#
# Usage:
#   ./add_music.sh [--dry-run] [MUSIC_ROOT]
#
# Default MUSIC_ROOT: /Volumes/Blackbox E Red/Music
#
# What it does:
#   1. Scans all audio files in format subdirs (flac, m4a, mp3, mp3-purchased, mp4, wma)
#   2. Optionally merges files from sibling dirs (Music-files, Music-videos)
#   3. Extracts metadata via mutagen + ffprobe
#   4. Verifies/corrects metadata against MusicBrainz
#   5. Attempts MusicBrainz text search for unidentified files
#   6. Deduplicates across formats (flac > m4a > mp3-purchased > mp3 > mp4 > wma)
#   7. Moves everything into Artist/Album/## Title.ext structure
#   8. Cleans up empty directories
#
# Options:
#   --dry-run   Show what would happen without making changes
#
# Requirements (auto-installed if missing): ffmpeg, chromaprint, python3 venv with mutagen + requests
#
set -euo pipefail

DRY_RUN=false
MUSIC_ROOT=""

# Parse args
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        -h|--help)
            echo "Usage: add_music.sh [--dry-run] [MUSIC_ROOT]"
            echo "  --dry-run   Show what would happen without making changes"
            echo "  MUSIC_ROOT  Path to music library (default: /Volumes/Blackbox E Red/Music)"
            exit 0
            ;;
        *) MUSIC_ROOT="$arg" ;;
    esac
done

[[ -z "$MUSIC_ROOT" ]] && MUSIC_ROOT="/Volumes/Blackbox E Red/Music"

VENV_DIR="/tmp/music-organizer-venv"
WORK_DIR="/tmp/music-organizer-$(date +%Y%m%d_%H%M%S)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── 0. Validate ──────────────────────────────────────────────────────────────
if [[ ! -d "$MUSIC_ROOT" ]]; then
    error "Music root not found: $MUSIC_ROOT"
    exit 1
fi
mkdir -p "$WORK_DIR"
info "Music root: $MUSIC_ROOT"
info "Working dir: $WORK_DIR"
$DRY_RUN && info "Mode: DRY-RUN (no files will be changed)"

# ── 1. Dependencies ─────────────────────────────────────────────────────────
install_deps() {
    info "Checking dependencies..."
    if ! command -v ffprobe &>/dev/null; then
        info "Installing ffmpeg..."
        brew install ffmpeg
    fi
    if ! command -v fpcalc &>/dev/null; then
        info "Installing chromaprint..."
        brew install chromaprint
    fi
    if [[ ! -d "$VENV_DIR" ]] || ! "$VENV_DIR/bin/python3" -c "import mutagen, requests" &>/dev/null; then
        info "Setting up Python venv..."
        python3 -m venv "$VENV_DIR"
        "$VENV_DIR/bin/pip" install -q mutagen requests
    fi
    info "Dependencies ready."
}
install_deps

PYTHON="$VENV_DIR/bin/python3"

# ── 2. Check for sibling directories to merge ───────────────────────────────
PARENT_DIR="$(dirname "$MUSIC_ROOT")"
MERGE_DIRS=()
for candidate in "$PARENT_DIR/Music-files" "$PARENT_DIR/Music-videos"; do
    if [[ -d "$candidate" ]]; then
        count=$(find "$candidate" -type f ! -name '.*' ! -name 'desktop.ini' ! -name 'Thumbs.db' 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$count" -gt 0 ]]; then
            MERGE_DIRS+=("$candidate")
            info "Found merge candidate: $candidate ($count files)"
        fi
    fi
done

if [[ ${#MERGE_DIRS[@]} -gt 0 ]] && ! $DRY_RUN; then
    echo ""
    read -rp "Merge these directories into $MUSIC_ROOT? [Y/n] " merge_answer
    if [[ "${merge_answer,,}" == "n" ]]; then
        MERGE_DIRS=()
        info "Skipping merge."
    fi
elif [[ ${#MERGE_DIRS[@]} -gt 0 ]] && $DRY_RUN; then
    info "[DRY RUN] Would prompt to merge ${#MERGE_DIRS[@]} sibling directory(ies)"
fi

# ── 3. Extract metadata + verify + plan + execute (single Python script) ────
info "Starting music organization pipeline..."

DRY_RUN_FLAG=""
$DRY_RUN && DRY_RUN_FLAG="--dry-run"

"$PYTHON" - "$MUSIC_ROOT" "$WORK_DIR" $DRY_RUN_FLAG "${MERGE_DIRS[@]+"${MERGE_DIRS[@]}"}" <<'PYTHON_SCRIPT'
import json, os, re, shutil, subprocess, sys, time
from collections import defaultdict
from pathlib import Path

# Check for --dry-run flag
DRY_RUN = "--dry-run" in sys.argv
args = [a for a in sys.argv[1:] if a != "--dry-run"]

MUSIC_ROOT = args[0]
WORK_DIR = args[1]
MERGE_DIRS = args[2:] if len(args) > 2 else []

sys.path.insert(0, os.path.join(os.environ.get("VIRTUAL_ENV", "/tmp/music-organizer-venv"), "lib"))
# Find the actual site-packages
for p in Path("/tmp/music-organizer-venv/lib").rglob("site-packages"):
    sys.path.insert(0, str(p))
    break

import mutagen
import requests

AUDIO_EXTS = {".mp3",".flac",".m4a",".m4b",".mp4",".wma",".ogg",".wav",".aac",".mkv",".avi",".mov"}
IMAGE_EXTS = {".jpg",".jpeg",".png",".gif",".bmp"}
FORMAT_PRIORITY = {"flac":1,"m4a":2,"mp3-purchased":3,"mp3":4,"mp4":5,"wma":6}
EXT_TO_FMT = {".mp3":"mp3",".flac":"flac",".m4a":"m4a",".m4b":"m4a",".mp4":"mp4",
              ".mkv":"mp4",".avi":"mp4",".mov":"mp4",".wma":"wma",".ogg":"mp3",
              ".wav":"flac",".aac":"m4a"}

session = requests.Session()
session.headers["User-Agent"] = "MusicOrganizer/2.0 (add_music.sh)"
last_mb_req = 0

def rate_limit():
    global last_mb_req
    elapsed = time.time() - last_mb_req
    if elapsed < 1.1: time.sleep(1.1 - elapsed)
    last_mb_req = time.time()

# ── Metadata extraction ─────────────────────────────────────────────────────

def extract_mutagen(fp):
    try:
        audio = mutagen.File(fp, easy=True)
        if audio is None: return None
        def first(tag):
            v = audio.get(tag)
            return str(v[0]).strip() if v and len(v)>0 else None
        artist = first("artist") or first("albumartist") or first("performer")
        album = first("album")
        title = first("title")
        track = disc = None
        t = first("tracknumber")
        if t:
            m = re.match(r"(\d+)", t)
            if m: track = int(m.group(1))
        d = first("discnumber")
        if d:
            m = re.match(r"(\d+)", d)
            if m: disc = int(m.group(1))
        return {"artist":artist,"album":album,"title":title,"track":track,"disc":disc,"source":"mutagen"}
    except: return None

def extract_ffprobe(fp):
    try:
        r = subprocess.run(["ffprobe","-v","quiet","-print_format","json","-show_format",fp],
                           capture_output=True,text=True,timeout=10)
        if r.returncode!=0: return None
        tags = json.loads(r.stdout).get("format",{}).get("tags",{})
        if not tags: return None
        tl = {k.lower():v for k,v in tags.items()}
        artist = tl.get("artist") or tl.get("album_artist") or tl.get("performer")
        album, title = tl.get("album"), tl.get("title")
        track = disc = None
        if tl.get("track"):
            m = re.match(r"(\d+)",str(tl["track"]))
            if m: track = int(m.group(1))
        if tl.get("disc"):
            m = re.match(r"(\d+)",str(tl["disc"]))
            if m: disc = int(m.group(1))
        if not any([artist,album,title]): return None
        return {"artist":artist.strip() if artist else None,"album":album.strip() if album else None,
                "title":title.strip() if title else None,"track":track,"disc":disc,"source":"ffprobe"}
    except: return None

def parse_filename(fp):
    stem = Path(fp).stem
    m = re.match(r"^[\d\-]+\s+(.+?)\s*[-\u2013\u2014]\s*(.+)$", stem)
    if m: return {"artist":m.group(1).strip(),"album":None,"title":m.group(2).strip(),
                  "track":None,"disc":None,"source":"filename"}
    m = re.match(r"^(.+?)\s*[-\u2013\u2014]\s*(.+)$", stem)
    if m and not re.match(r"^\d+$",m.group(1).strip()):
        return {"artist":m.group(1).strip(),"album":None,"title":m.group(2).strip(),
                "track":None,"disc":None,"source":"filename"}
    m = re.match(r"^(\d{1,2})(?:-(\d{2}))?\s+(.+)$", stem)
    if m:
        track, disc = (int(m.group(1)),None) if not m.group(2) else (int(m.group(2)),int(m.group(1)))
        return {"artist":None,"album":None,"title":m.group(3).strip(),"track":track,"disc":disc,"source":"filename"}
    return None

def track_from_filename(fp):
    m = re.match(r"^(\d{1,2})(?:-(\d{2}))?\s+", Path(fp).stem)
    if m:
        if m.group(2): return int(m.group(2)), int(m.group(1))
        return int(m.group(1)), None
    return None, None

# ── Scanning ─────────────────────────────────────────────────────────────────

def scan_dir(root_dir, source_label):
    entries = []
    count = 0
    for root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for fname in files:
            if fname.startswith(".") or fname.lower() in ("desktop.ini","thumbs.db"): continue
            fp = os.path.join(root, fname)
            ext = os.path.splitext(fname)[1].lower()
            if ext in IMAGE_EXTS:
                entries.append({"path":fp,"source":source_label,"fmt":None,"ext":ext,
                                "type":"artwork","meta":None,"needs_fp":False})
                continue
            if ext not in AUDIO_EXTS: continue
            count += 1
            if count % 200 == 0: print(f"  [{source_label}] Scanned {count}...", flush=True)

            meta = extract_mutagen(fp)
            if meta is None or not any([meta.get("artist"),meta.get("title")]):
                ff = extract_ffprobe(fp)
                if ff and any([ff.get("artist"),ff.get("title")]): meta = ff

            if meta and meta.get("track") is None:
                t, d = track_from_filename(fp)
                if t: meta["track"] = t
                if d and not meta.get("disc"): meta["disc"] = d

            needs_fp = False
            if not meta or not meta.get("artist") or not meta.get("title"):
                fn = parse_filename(fp)
                if fn:
                    if meta is None: meta = fn
                    else:
                        for k in ["artist","title","album","track","disc"]:
                            if not meta.get(k) and fn.get(k): meta[k] = fn[k]
                if not meta or not meta.get("artist") or not meta.get("title"):
                    needs_fp = True

            fmt = EXT_TO_FMT.get(ext, "mp3")
            entries.append({"path":fp,"source":source_label,"fmt":fmt,"ext":ext,
                            "type":"audio","meta":meta,"needs_fp":needs_fp})
    print(f"  [{source_label}] Total: {count} audio files", flush=True)
    return entries

# ── MusicBrainz verification ────────────────────────────────────────────────

def mb_search(artist, title, album=None):
    rate_limit()
    try:
        parts = []
        if artist: parts.append(f'artist:"{artist}"')
        if title: parts.append(f'recording:"{title}"')
        if album: parts.append(f'release:"{album}"')
        q = " AND ".join(parts)
        r = session.get("https://musicbrainz.org/ws/2/recording/",
                        params={"query":q,"fmt":"json","limit":5}, timeout=15)
        if r.status_code != 200: return None
        recs = r.json().get("recordings",[])
        if not recs or recs[0].get("score",0) < 70: return None
        rec = recs[0]
        mb_artist = None
        if rec.get("artist-credit"):
            p = []
            for ac in rec["artist-credit"]:
                p.append(ac.get("name",ac.get("artist",{}).get("name","")))
                if ac.get("joinphrase"): p.append(ac["joinphrase"])
            mb_artist = "".join(p).strip()
        mb_album = rec["releases"][0]["title"] if rec.get("releases") else None
        mb_track = None; mb_disc = None
        if rec.get("releases"):
            best = None
            if album:
                for rel in rec["releases"]:
                    if rel.get("title","").lower() == album.lower(): best = rel; break
            if not best: best = rec["releases"][0]
            mb_album = best.get("title")
            for medium in best.get("media",[]):
                for trk in medium.get("track",[]):
                    if trk.get("title","").lower() == (rec.get("title") or "").lower():
                        try: mb_track = int(trk["number"])
                        except: pass
                        mb_disc = medium.get("position")
                        break
        return {"artist":mb_artist,"title":rec.get("title"),"album":mb_album,
                "track":mb_track,"disc":mb_disc,"score":rec["score"]}
    except: return None

def mb_text_search(text):
    rate_limit()
    clean = text
    for pat in [r'\(Official\s*(Music\s*)?Video\)',r'\(Official\s*Audio\)',r'\(Lyric\s*Video\)',
                r'\(Lyrics?\)',r'\[Official.*?\]',r'\(HD\)',r'\(HQ\)',r'\d+D\s*AUDIO',
                r'[\U0001f507\U0001f4ab\U0001f3b5\U0001f3b6]',r'\(better than.*?\)']:
        clean = re.sub(pat,'',clean,flags=re.IGNORECASE)
    for sep in ['~','\u2013','\u2014','-']:
        m = re.match(rf'^(.+?)\s*{re.escape(sep)}\s*(.+)$', clean.strip())
        if m and not re.match(r'^\d+$',m.group(1).strip()):
            return mb_search(m.group(1).strip(), m.group(2).strip())
    m = re.match(r'^(.+?)\s+by\s+(.+)$', clean.strip(), re.IGNORECASE)
    if m: return mb_search(m.group(2).strip(), m.group(1).strip())
    try:
        r = session.get("https://musicbrainz.org/ws/2/recording/",
                        params={"query":f'recording:"{clean.strip()}"',"fmt":"json","limit":3}, timeout=15)
        if r.status_code==200:
            recs = r.json().get("recordings",[])
            if recs and recs[0].get("score",0)>=80:
                rec = recs[0]
                artist = None
                if rec.get("artist-credit"):
                    p = []
                    for ac in rec["artist-credit"]:
                        p.append(ac.get("name",ac.get("artist",{}).get("name","")))
                        if ac.get("joinphrase"): p.append(ac["joinphrase"])
                    artist = "".join(p).strip()
                album = rec["releases"][0]["title"] if rec.get("releases") else None
                return {"artist":artist,"title":rec.get("title"),"album":album,"score":rec["score"]}
    except: pass
    return None

# ── Path building ────────────────────────────────────────────────────────────

def sanitize(name):
    if not name: return "Unknown"
    name = re.sub(r'[/\\:]','-',name)
    name = re.sub(r'[<>"|?*]','',name)
    name = name.strip('. ')
    name = re.sub(r'\s+',' ',name)
    return name if name else "Unknown"

def build_target(entry):
    meta = entry.get("meta")
    if not meta or not meta.get("artist") or not meta.get("title"): return None
    artist = sanitize(meta["artist"])
    album = sanitize(meta.get("album") or "Unknown Album")
    title = sanitize(meta["title"])
    ext = entry["ext"]
    track, disc = meta.get("track"), meta.get("disc")
    if track:
        fname = f"{disc}-{track:02d} {title}{ext}" if disc and disc > 1 else f"{track:02d} {title}{ext}"
    else:
        fname = f"{title}{ext}"
    return os.path.join(MUSIC_ROOT, entry["fmt"], artist, album, fname)

# ── Main pipeline ────────────────────────────────────────────────────────────

print("\n=== Phase 1: Scanning files ===", flush=True)
all_entries = scan_dir(MUSIC_ROOT, "Music")
for md in MERGE_DIRS:
    all_entries.extend(scan_dir(md, os.path.basename(md)))

audio = [e for e in all_entries if e["type"]=="audio"]
has_meta = sum(1 for e in audio if e.get("meta") and e["meta"].get("artist") and e["meta"].get("title"))
needs_fp = sum(1 for e in audio if e.get("needs_fp"))
print(f"\n  Audio files: {len(audio)}, Identified: {has_meta}, Need lookup: {needs_fp}", flush=True)

# Phase 2: MusicBrainz verification
print("\n=== Phase 2: MusicBrainz verification ===", flush=True)
verify_count = sum(1 for e in audio if not e.get("needs_fp") and e.get("meta") and e["meta"].get("artist") and e["meta"].get("title"))
verified = corrected = done = 0
for entry in audio:
    if entry.get("needs_fp") or not entry.get("meta") or not entry["meta"].get("artist") or not entry["meta"].get("title"):
        continue
    done += 1
    if done % 50 == 0:
        print(f"  Verifying: {done}/{verify_count} (verified: {verified}, corrected: {corrected})", flush=True)
    meta = entry["meta"]
    result = mb_search(meta.get("artist"), meta.get("title"), meta.get("album"))
    if result and result.get("score",0) >= 85:
        verified += 1
        changes = False
        if result.get("artist") and result["artist"] != meta.get("artist"):
            meta["artist"] = result["artist"]; changes = True
        if result.get("title") and result["title"] != meta.get("title"):
            meta["title"] = result["title"]; changes = True
        if result.get("album") and not meta.get("album"):
            meta["album"] = result["album"]; changes = True
        if result.get("track") and not meta.get("track"):
            meta["track"] = result["track"]; changes = True
        if changes: corrected += 1
print(f"  Done: {verified} verified, {corrected} corrected out of {verify_count}", flush=True)

# Phase 3: Text search for unknowns
print("\n=== Phase 3: Text search for unknowns ===", flush=True)
unknowns = [e for e in audio if not e.get("meta") or not e["meta"].get("artist") or not e["meta"].get("title")]
skip_patterns = [r'^Voice \d+',r'^New Recording',r'^\d+ Hz',r'^ANGEL MUSIC',
                 r'^Healing',r'^meditation',r'^frequency',r'shamanic']
fixed = 0
for i, entry in enumerate(unknowns):
    if (i+1) % 10 == 0: print(f"  Searching: {i+1}/{len(unknowns)} (fixed: {fixed})", flush=True)
    meta = entry.get("meta") or {}
    text = meta.get("title") or os.path.splitext(os.path.basename(entry["path"]))[0]
    if not text or len(text) < 3: continue
    if any(re.search(p, text, re.IGNORECASE) for p in skip_patterns): continue
    result = mb_text_search(text)
    if result and result.get("artist") and result.get("title"):
        fixed += 1
        if entry["meta"] is None: entry["meta"] = {}
        entry["meta"]["artist"] = result["artist"]
        entry["meta"]["title"] = result["title"]
        if result.get("album"): entry["meta"]["album"] = result["album"]
        entry["needs_fp"] = False
print(f"  Fixed: {fixed}/{len(unknowns)}", flush=True)

# Phase 4: Dedup
print("\n=== Phase 4: Deduplication ===", flush=True)
groups = defaultdict(list)
unsorted_entries = []
for e in audio:
    meta = e.get("meta")
    if not meta or not meta.get("artist") or not meta.get("title"):
        unsorted_entries.append(e)
        continue
    key = (meta["artist"].lower().strip(), meta["title"].lower().strip(), (meta.get("album") or "").lower().strip())
    groups[key].append(e)

kept, removed = [], []
for key, group in groups.items():
    if len(group)==1: kept.append(group[0]); continue
    group.sort(key=lambda e: FORMAT_PRIORITY.get(e.get("fmt","mp3"),99))
    kept.append(group[0])
    removed.extend(group[1:])
print(f"  Keeping: {len(kept)}, Duplicates to remove: {len(removed)}, Unsorted: {len(unsorted_entries)}", flush=True)

# Phase 5: Generate moves
print("\n=== Phase 5: Planning moves ===", flush=True)
moves, unsorted_moves, no_move = [], [], []
for entry in kept:
    target = build_target(entry)
    if not target: continue
    if os.path.normpath(entry["path"])==os.path.normpath(target): no_move.append(entry["path"]); continue
    moves.append({"src":entry["path"],"tgt":target})
for entry in unsorted_entries:
    fmt = entry.get("fmt","mp3")
    fname = os.path.basename(entry["path"])
    tgt = os.path.join(MUSIC_ROOT, fmt, "_unsorted", fname)
    unsorted_moves.append({"src":entry["path"],"tgt":tgt})

# Resolve collisions
tgt_map = defaultdict(list)
for m in moves: tgt_map[m["tgt"]].append(m)
for tgt, ms in tgt_map.items():
    if len(ms)<=1: continue
    base, ext = os.path.splitext(tgt)
    for i, m in enumerate(ms[1:],2): m["tgt"] = f"{base} ({i}){ext}"

print(f"  To move: {len(moves)}, To unsorted: {len(unsorted_moves)}, Already correct: {len(no_move)}, Duplicates: {len(removed)}", flush=True)

# Save plan for review
plan = {"moves":len(moves),"unsorted":len(unsorted_moves),"correct":len(no_move),"duplicates":len(removed)}
plan_path = os.path.join(WORK_DIR, "plan_summary.json")
with open(plan_path,"w") as f: json.dump(plan,f)

# Ask for confirmation
print(f"\n{'='*60}", flush=True)
print(f"  FILES TO MOVE/RENAME:    {len(moves)}", flush=True)
print(f"  FILES TO _unsorted:      {len(unsorted_moves)}", flush=True)
print(f"  ALREADY CORRECT:         {len(no_move)}", flush=True)
print(f"  DUPLICATES TO DELETE:    {len(removed)}", flush=True)
print(f"{'='*60}", flush=True)

if DRY_RUN:
    print("\n[DRY RUN] No files were changed. Review the plan above.")
    print(f"Plan saved to: {plan_path}")
    sys.exit(0)

confirm = input("\nProceed with execution? [Y/n] ").strip().lower()
if confirm == "n":
    print("Aborted. No files were changed.")
    sys.exit(0)

# Phase 6: Execute
print("\n=== Phase 6: Executing ===", flush=True)
moved = errors = 0
for i, m in enumerate(moves):
    if (i+1)%200==0: print(f"  Moving: {i+1}/{len(moves)}", flush=True)
    try:
        os.makedirs(os.path.dirname(m["tgt"]), exist_ok=True)
        tgt = m["tgt"]
        if os.path.exists(tgt):
            base, ext = os.path.splitext(tgt)
            c = 2
            while os.path.exists(f"{base} ({c}){ext}"): c += 1
            tgt = f"{base} ({c}){ext}"
        shutil.move(m["src"], tgt); moved += 1
    except Exception as e: errors += 1

unsorted_done = 0
for u in unsorted_moves:
    try:
        os.makedirs(os.path.dirname(u["tgt"]), exist_ok=True)
        tgt = u["tgt"]
        if os.path.exists(tgt):
            base, ext = os.path.splitext(tgt)
            c = 2
            while os.path.exists(f"{base} ({c}){ext}"): c += 1
            tgt = f"{base} ({c}){ext}"
        shutil.move(u["src"], tgt); unsorted_done += 1
    except: pass

dup_done = 0
for e in removed:
    try:
        if os.path.exists(e["path"]): os.remove(e["path"]); dup_done += 1
    except: pass

# Cleanup empty dirs
cleaned = 0
for root_dir in [MUSIC_ROOT] + MERGE_DIRS:
    if not os.path.isdir(root_dir): continue
    for dirpath, dirnames, filenames in os.walk(root_dir, topdown=False):
        if dirpath == root_dir: continue
        real = [f for f in filenames if not f.startswith(".") and f.lower() not in ("desktop.ini","thumbs.db")]
        if not real and not dirnames:
            for f in filenames:
                try: os.remove(os.path.join(dirpath,f))
                except: pass
            try: os.rmdir(dirpath); cleaned += 1
            except: pass

print(f"\n{'='*60}", flush=True)
print(f"  FILES MOVED:           {moved}", flush=True)
print(f"  UNSORTED MOVED:        {unsorted_done}", flush=True)
print(f"  DUPLICATES REMOVED:    {dup_done}", flush=True)
print(f"  EMPTY DIRS CLEANED:    {cleaned}", flush=True)
if errors: print(f"  ERRORS:                {errors}", flush=True)
print(f"{'='*60}", flush=True)
print("\nDone!", flush=True)
PYTHON_SCRIPT

info "Music organization complete."
