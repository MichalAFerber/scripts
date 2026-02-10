# Scripts

A collection of automation scripts for backup management, self-hosted services, media libraries, DNS infrastructure, and system maintenance. Built around a home lab running Immich, Plex, Unbound, and Wasabi S3 storage.

## Repository Structure

```
scripts/
├── backup-kit/              # 3-2-1 backup strategy (Restic + rclone)
├── browser/                 # Chrome extension snippets
├── cloudflare/              # Cloudflare domain & DNS management
├── comics/                  # Comic book file processing (CBZ/CBR)
├── docker/                  # Docker Compose utilities
├── downloaders/             # YouTube, TikTok, X, Telegram downloaders
├── immich/                  # Immich photo management & Ente migration
├── obsidian/                # Obsidian vault CSS customizations
├── plex-media-server/       # Plex library organization & metadata
├── powershell/              # Windows system administration
├── rclone/                  # Wasabi S3 cloud storage tools
├── rsync/                   # File sync & Raspberry Pi backups
├── sysmaint/                # Linux server maintenance automation
├── tools/                   # General-purpose file utilities
├── unbound/                 # Recursive DNS resolver (dual Pi setup)
└── wasabi-universal-backup/ # Cross-platform Wasabi S3 backup suite
```

---

## backup-kit

Automated 3-2-1 backup strategy for macOS, Linux, and self-hosted services. Includes systemd timers and cron scheduling.

| Script | Description |
|--------|-------------|
| `macos-restic-backup.sh` | Encrypted macOS backups via Restic to S3 |
| `linux-offsite-sync.sh` | Linux/Pi snapshot sync via rclone |
| `immich-backup.sh` | Immich DB dump + uploads sync |
| `github-mirror.sh` | Full GitHub organization mirror |
| `npm-backup.sh` | Nginx Proxy Manager volume backup |

**Tools:** restic, rclone, pg_dump, gh, jq

See [`backup-kit/README.md`](backup-kit/README.md) for setup and scheduling.

---

## browser

Chrome extension code for browser automation.

| Script | Description |
|--------|-------------|
| `base.js` | Extension base functionality and DOM utilities |
| `chrome.runtime.onMessage.js` | Chrome message handler for extension actions |

---

## cloudflare

Cloudflare domain management and DNS tools.

| Script | Description |
|--------|-------------|
| `cf_trace_domains.py` | Trace all domains across Cloudflare accounts, generate HTML/JSON reports |
| `cf_configure_redirects.py` | Bulk configure page rules and redirects |
| `domains.sh` | List domains in a Cloudflare account |
| `get_expires.sh` | Check domain expiration dates |

**Requires:** `CF_API_KEY` and `CF_API_EMAIL` environment variables

---

## comics

CBZ/CBR comic book file processing and metadata management.

| Script | Description |
|--------|-------------|
| `generate_comicinfo.sh` | Create ComicInfo.xml metadata for CBZ files |
| `process_comic_amazing_man.sh` | Specialized processing for "Amazing Man" series |
| `process_comics.sh` | Batch rename to "Series #001 (YYYY)" format, normalize CBR/CBZ, embed ComicInfo.xml |
| `rename_comic_amazing_man.sh` | Rename Amazing Man issues to standard format |

**Features:** Dry-run mode, logging, ZIP-as-CBR detection

---

## docker

Docker Compose utilities.

| Script | Description |
|--------|-------------|
| `update-compose.sh` | Pull latest images and recreate Docker Compose projects |

---

## downloaders

Video and media download tools supporting multiple platforms.

| Script | Description |
|--------|-------------|
| `download_x.sh` | Twitter/X media downloader |
| `telegram_dl.py` | Telegram channel media downloader |
| `universal_downloader.sh` | YouTube/Rumble/TikTok/X downloader with batch mode (TXT/CSV) |

**Tools:** yt-dlp

---

## immich

Photo management and migration tools for [Immich](https://immich.app/) (self-hosted photo backup). Includes scripts for migrating from Ente and uploading from various sources.

| Script | Description |
|--------|-------------|
| `add_missing_by_filename_indexed.py` | Filename-based asset matching and upload |
| `add_missing_from_dump.py` | Reconcile and upload missing assets from dump files |
| `compare_ente_to_immich.py` | Compare assets between Ente and Immich by timestamp |
| `compare_ente_vs_immich_by_album.py` | Album-level comparison between services |
| `dump_immich_albums.py` | Export album metadata from Immich API |
| `dump_immich_albums_detailed.py` | Export detailed album metadata with asset lists |
| `dump_immich_assets.py` | Export all asset metadata from Immich |
| `fill_missing_from_ente_export.sh` | Migrate photos from Ente encrypted export |
| `fill_missing_from_mando.sh` | Upload missing photos from external drive using Spotlight search |
| `make_it_green.sh` | Validate asset integrity across albums |
| `retag_from_staging.sh` | Re-tag photos from staging directory |
| `validate_and_sweep.sh` | Validate and clean up uploaded assets |

**Tools:** curl, jq, immich-cli | **Requires:** `IMMICH_API_KEY` environment variable

See [`immich/ente_to_immich_migration.md`](immich/ente_to_immich_migration.md) for the full Ente migration guide.

---

## obsidian

Custom styles for Obsidian note-taking.

| File | Description |
|------|-------------|
| `print-clean.css` | Clean print stylesheet for Obsidian notes |

---

## plex-media-server

Plex library organization, metadata standardization, and file renaming tools.

| Script | Description |
|--------|-------------|
| `apply_official_titles_wwpv.py` | Apply official title mappings to WWPV episodes |
| `plex_sync_check.sh` | Verify movie sync between sources |
| `plex_wwpv_renamer.py` | Rename "What We Do In The Shadows" episodes to official titles |
| `plex-xml.py` | Parse Plex XML metadata |
| `rename_movies.py` | Auto-rename movies to "Title (YYYY).ext" format with IMDb lookup |
| `rename_movies_for_plex.py` | Batch rename for Plex naming compliance |
| `sync_movies.sh` | Sync movie folder to Plex library |
| `undo_plex_wwpv_rename.py` | Rollback WWPV renames |
| `xml-plex-compare.py` | Compare Plex library XML files |

**Tools:** cinemagoer (IMDb library)

---

## powershell

Windows system administration scripts.

| Script | Description |
|--------|-------------|
| `Install-ServerPrerequisites.ps1` | Install Windows server dependencies |
| `dotnet-install.ps1` | .NET Framework/Core installer |
| `UrlRewriteResources.ps1` | IIS URL Rewrite module setup |
| `VMAssignableDevice.ps1` | GPU passthrough for Hyper-V VMs |
| `Archive-ExtraOneDriveFolders.ps1` | Archive old OneDrive folders |
| `Zip-ExtraOneDriveFolders.ps1` | Compress OneDrive folders |

---

## rclone

Cloud storage management via rclone, targeting Wasabi S3.

| Script | Description |
|--------|-------------|
| `rclone-wasabi-ferber-storage.sh` | Copy/sync local folders to Wasabi S3 with verification and dry-run |
| `wasabi-consolidate.sh` | Consolidate and deduplicate Wasabi storage |
| `s3_backup.py` | Python S3 backup wrapper with incremental sync |

**Tools:** rclone | **Requires:** Wasabi S3 credentials configured as an rclone remote

---

## rsync

File synchronization and Raspberry Pi backup infrastructure.

| Script | Description |
|--------|-------------|
| `sync_folders.sh` | Bidirectional folder sync wrapper |
| `sync_folders_option1.py` | Python rsync wrapper (option 1) |
| `sync_folders_option2.py` | Python rsync wrapper (option 2) |

### rsync/raspberry-pi

Automated Raspberry Pi to Synology NAS backup system with systemd scheduling.

| Script | Description |
|--------|-------------|
| `pi-to-synology-snapshot.sh` | Snapshot Pi to NAS via rsync |
| `pi-backup-prune.sh` | Prune old backup snapshots |
| `pi-restore.sh` | Restore from NAS backup |
| `install-pi-synology-backup.sh` | Installation script |
| `netinstall-pi-synology-backup.sh` | Network installation script |

---

## sysmaint

All-in-one Linux server maintenance automation with email notifications.

| Script | Description |
|--------|-------------|
| `sysmaint.sh` | APT updates, Docker Compose refresh, container updates, auto-reboot |
| `notify.py` | SMTP email notification sender |
| `config.json` | SMTP configuration template |

**Features:** Interactive menu or non-interactive flags, email notifications via SMTP

See [`sysmaint/README.md`](sysmaint/README.md) for configuration.

---

## tools

General-purpose file management utilities.

| Script | Description |
|--------|-------------|
| `backup_manager.py` | Manage backup retention and archiving |
| `compare_files_based_on_hash.py` | Compare files by checksum |
| `duplicate_detector.py` | Detect duplicate files across directories |
| `duplicate_finder.py` | Find and manage duplicate files using MD5 hash comparison |

---

## unbound

Recursive DNS resolver setup for a home lab, running on two Raspberry Pi 4s with automated config sync.

| Script | Description |
|--------|-------------|
| `install.sh` | Unbound installation and configuration |
| `update_dns.sh` | DNS zone update automation |
| `update-unbound-root-hints.sh` | Refresh root hints |
| `sync-to-peer.sh` | Sync configuration to redundant Pi |
| `dns-check.sh` | DNS resolution validation |

**Features:** DNSSEC, local authoritative zone (`mykk.foo`), redundant resolution, caching

See [`unbound/README.md`](unbound/README.md) for full architecture and setup.

---

## wasabi-universal-backup

Cross-platform backup suite targeting Wasabi S3, with both Bash and PowerShell implementations.

| Script | Description |
|--------|-------------|
| `universal_backup.ps1` | PowerShell version (Windows) |
| `universal_backup.sh` | Bash version (macOS/Linux) |

**Features:** CLI-first with interactive prompts, dry-run mode, concurrent transfers, bandwidth throttling, auto-dated subfolders, GitHub Actions integration

See [`wasabi-universal-backup/README.md`](wasabi-universal-backup/README.md) for usage and configuration.

---

## Languages

| Language | Usage |
|----------|-------|
| Bash | Backup automation, system maintenance, media processing |
| JavaScript | Browser extension code |
| PowerShell | Windows server administration, cross-platform backup |
| Python | API integrations (Immich, Cloudflare), file utilities, Plex metadata |

## Common Dependencies

| Tool | Used By |
|------|---------|
| [cinemagoer](https://cinemagoer.github.io/) | plex-media-server |
| [curl](https://curl.se/) | cloudflare, immich, unbound |
| [docker](https://www.docker.com/) | sysmaint, docker |
| [gh](https://cli.github.com/) | backup-kit |
| [immich-cli](https://immich.app/docs/features/command-line-interface) | immich |
| [jq](https://jqlang.github.io/jq/) | backup-kit, cloudflare, immich |
| [rclone](https://rclone.org/) | backup-kit, rclone, wasabi-universal-backup |
| [restic](https://restic.net/) | backup-kit |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | downloaders |

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
