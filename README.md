# Michal Ferber's Useful Scripts

A curated collection of personal scripts and utilities organized by application or task. These scripts range from media management, system maintenance, to Docker service helpers, and Kavita-specific renaming tools.

## Table of Contents

- [Michal Ferber's Useful Scripts](#michal-ferbers-useful-scripts)
  - [Table of Contents](#table-of-contents)
  - [comics/](#comics)
  - [docker/](#docker)
  - [kavita/](#kavita)
  - [plex-media-server/](#plex-media-server)
  - [rsync/](#rsync)
  - [📦 External Script Projects](#-external-script-projects)
  - [Usage](#usage)
  - [License](#license)

## comics/

| Script               | Description                                               |
|----------------------|-----------------------------------------------------------|
| process_comics | Shell script to automatically rename and optionally convert `.cbr` files to `.cbz`, generate embedded `ComicInfo.xml`. |

## docker/

| Script               | Description                                               |
|----------------------|-----------------------------------------------------------|
| start-docker-services.sh | Automates starting and monitoring multiple Docker Compose services and standalone containers, including health checks and network management. |

## kavita/

| Script               | Description                                               |
|----------------------|-----------------------------------------------------------|
| rename_comics.py     | Renames comic book files to Kavita naming conventions, with issue/year detection and backup of originals. |
| rename_magazines.py  | Renames magazine files to Kavita naming conventions, supports issue/year mapping, special issues, and backups originals. |

## plex-media-server/

| Script               | Description                                                             |
|----------------------|-------------------------------------------------------------------------|
| plex-xml.py          | Parses Plex library XML export to generate a CSV list of all movies.    |
| plex-xml-compare.py  | Compares Plex library XML export against local media directory files to find discrepancies. |

## rsync/

| Script               | Description                                               |
|----------------------|-----------------------------------------------------------|
| sync_folders.py      | Synchronizes two folders bidirectionally using `rsync`, with logging and error handling. |

## 📦 External Script Projects

These are maintained in dedicated repositories but are part of my broader toolset:

- [`welcome-message`](https://github.com/MichalAFerber/welcome-message)  
  ✨ Auto-installs a custom login banner with system info, Fastfetch, and multi-language support.

- [`IMDbMovieFileFixer`](https://github.com/MichalAFerber/IMDbMovieFileFixer)  
  🎬 Renames movie files using IMDb metadata—ideal for tidying up Plex and Jellyfin libraries.

## Usage

- Most scripts are standalone and require Python 3 or bash.
- Navigate into the script's folder or run scripts with full path.
- Review script comments at the top for any specific usage instructions or configuration needed.
- Kavita scripts assume specific folder structures and may require customizing base directories.
- Docker scripts require Docker and Docker Compose installed and configured.
- Rsync script requires `rsync` installed on the system.

## License

All scripts in this repository are licensed under the [MIT License](LICENSE).

---

Thank you for checking out my scripts! Feel free to fork, use, and improve them.
