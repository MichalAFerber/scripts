# add_music
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Organizes, verifies, and deduplicates a music library. Scans audio files across format subdirectories, extracts metadata using mutagen and ffprobe, verifies and corrects metadata against MusicBrainz, attempts text-based lookups for unidentified files, deduplicates across formats (preferring FLAC > M4A > MP3), reorganizes everything into Artist/Album/Track structure, and cleans up empty directories. Optionally merges files from sibling directories (Music-files, Music-videos).
### How to Use
Dependencies are auto-installed if missing: `ffmpeg`, `chromaprint` (via Homebrew), and a Python venv with `mutagen` + `requests`.

Dry-run (scan, verify, plan, but make no changes):
```
./add_music.sh --dry-run
./add_music.sh --dry-run /path/to/music
```
Full run with interactive confirmation before execution:
```
./add_music.sh
./add_music.sh /path/to/music
```
### What and Where to Tweak
- `MUSIC_ROOT` - First positional argument, or defaults to `/Volumes/Blackbox E Red/Music`
- `VENV_DIR` - Location for the Python virtual environment (default: `/tmp/music-organizer-venv`)
- `AUDIO_EXTS` (in Python section) - Set of audio file extensions to process
- `FORMAT_PRIORITY` (in Python section) - Dictionary controlling which format wins during deduplication (lower number = higher priority)
- `EXT_TO_FMT` (in Python section) - Mapping from file extensions to format subdirectory names
- `skip_patterns` (in Phase 3) - Regex patterns for filenames to skip during MusicBrainz text search
