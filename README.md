# 🛠 Michal's Script Collection

A collection of practical Bash scripts and helpers I use across my Linux systems, Raspberry Pi devices, and self-hosted environments.

## 📂 Scripts in This Repo

These are general-purpose scripts maintained directly in this repository:

| Folder              | Script              | Description                                                       |
|---------------------|---------------------|-------------------------------------------------------------------|
| plex-media-server | [plex-xml.py](plex-media-server/plex-xml.py) | Reads a Plex XML export (plex.xml) and extracts movie titles and file paths, saving them as a dated CSV for easy review or processing. |
| plex-media-server | [plex-xml-compare.py](plex-media-server/plex-xml-compare.py) | Compares the Plex XML movie list with the actual files present in a specified media directory (default /mnt/plexmedia), generating a CSV report that shows whether each movie file exists or is missing on disk. |
| rsync   | [sync_folders.py](rsync/sync_folders.py) | Performs a two-way sync using `rsync`, with logging, error handling, and optional `--dry-run`. |

> Note: You can clone and execute any of these directly.

## 📦 External Script Projects

These are maintained in dedicated repositories but are part of my broader toolset:

- [`welcome-message`](https://github.com/MichalAFerber/welcome-message)  
  ✨ Auto-installs a custom login banner with system info, Fastfetch, and multi-language support.

- [`IMDbMovieFileFixer`](https://github.com/MichalAFerber/IMDbMovieFileFixer)  
  🎬 Renames movie files using IMDb metadata—ideal for tidying up Plex and Jellyfin libraries.

## 🚀 Usage

You can run scripts directly or clone the repository:

```bash
git clone https://github.com/MichalAFerber/scripts.git
cd scripts
./ScriptFileName
```

🧠 License
All scripts in this repository are open source under the MIT License unless otherwise noted.

🙋‍♂️ Contributions
Suggestions, forks, and pull requests are welcome. This is a living collection of tools that evolve with my workflow.
