# Scripts Collection
## Michal Ferber
## Revised Date: 03/27/2026

A curated collection of automation scripts for home lab management, backup strategies, media organization, and system administration.

Every script that modifies, copies, moves, or deletes files supports a `--dry-run` flag (or `-DryRun`/`-WhatIf` for PowerShell) so you can preview changes before committing them.

---

### backup/
Cloud and local backup automation using restic, rclone, and Wasabi S3.

| Script | Description |
|--------|-------------|
| `macos-restic-backup.sh` | Encrypted macOS backups via Restic to S3 |
| `linux-offsite-sync.sh` | Linux/Pi snapshot sync via rclone |
| `immich-backup.sh` | Immich database dump + uploads sync |
| `github-mirror.sh` | Full GitHub organization/user repo mirror |
| `npm-backup.sh` | Nginx Proxy Manager volume backup |
| `universal_backup.sh` | Cross-platform backup suite (Bash) |
| `universal_backup.ps1` | Cross-platform backup suite (PowerShell) |
| `rclone-wasabi-ferber-storage.sh` | Local to Wasabi S3 copy/sync |
| `wasabi-consolidate.sh` | Consolidate and deduplicate Wasabi storage |
| `s3_backup.py` | Python incremental S3 backup |
| `sync_to_wasabi.sh` | Interactive Wasabi cloud sync for external drives |
| `wasabi-purge.sh` | Wrapper: `rclone delete --min-age 90d` + `rclone rmdirs --leave-root` |

### cloudflare/
Cloudflare domain management and diagnostics.

| Script | Description |
|--------|-------------|
| `cf_trace_domains.py` | Trace domains across all Cloudflare accounts |
| `cf_configure_redirects.py` | Bulk redirect and DNS configuration |

### comics/
Comic book archive processing and metadata management.

| Script | Description |
|--------|-------------|
| `process_comics.sh` | Batch rename, convert, and embed metadata for CBZ/CBR |
| `generate_comicinfo.sh` | Generate and embed ComicInfo.xml metadata |
| `rename_comic_amazing_man.sh` | Rename Amazing-Man files to standard format |
| `process_comic_amazing_man.sh` | Complete Amazing-Man processing pipeline |

### dns/
Unbound recursive DNS resolver setup and management.

| Script | Description |
|--------|-------------|
| `install.sh` | Unbound DNS installation and configuration |
| `update_dns.sh` | DNS zone update automation |
| `update-unbound-root-hints.sh` | Refresh root hints file |
| `sync-to-peer.sh` | Sync config to redundant DNS peer |
| `dns-check.sh` | DNS resolution validation |

### docker/
Docker Compose utilities.

| Script | Description |
|--------|-------------|
| `update-compose.sh` | Recursive Docker Compose project updater |

### downloaders/
Media download tools for various platforms.

| Script | Description |
|--------|-------------|
| `universal_downloader.sh` | Multi-platform downloader (YouTube, Rumble, TikTok, X) |
| `download_x.sh` | Twitter/X media downloader |
| `telegram_dl.py` | Telegram channel media downloader |

### file-tools/
File comparison, deduplication, and backup utilities.

| Script | Description |
|--------|-------------|
| `compare_files_based_on_hash.py` | Sync files between directories by MD5 hash |
| `duplicate_finder.py` | Interactive duplicate file detection and management |
| `backup_manager.py` | Incremental backup with compression and versioning |
| `duplicate_detector.py` | Fuzzy duplicate record detection for DataFrames |

### immich/
Immich photo management API tools.

| Script | Description |
|--------|-------------|
| `dump_immich_assets.py` | Export all Immich assets to JSON |
| `dump_immich_albums.py` | Export album metadata to JSON |
| `dump_immich_albums_detailed.py` | Export detailed album data with asset lists |
| `compare_ente_to_immich.py` | Compare Ente and Immich libraries by timestamp/filename |
| `compare_ente_vs_immich_by_album.py` | Album-level Ente vs Immich comparison |

### media/
Media library organization for Plex, books, and music.

| Script | Description |
|--------|-------------|
| `add-book.sh` | Add books to library with metadata extraction |
| `add_music.sh` | Organize, verify, and deduplicate music library |
| `rename_movies.py` | Auto-rename movie files via IMDb lookup |
| `rename_movies_for_plex.py` | Batch rename movies for Plex compliance |
| `plex_wwpv_renamer.py` | Rename WWDITS episodes |
| `apply_official_titles_wwpv.py` | Apply official WWDITS title mappings |
| `undo_plex_wwpv_rename.py` | Rollback WWDITS renames |
| `wwpv_official_titles_fix.py` | Fix WWDITS episode titles |
| `wwpv_specials_check.py` | Verify WWDITS special episodes |
| `xml-plex.py` | Extract Plex library titles and paths to CSV |
| `xml-plex-compare.py` | Compare Plex XML against filesystem |
| `sync_movies.sh` | Sync movie folder to Plex library |
| `plex_sync_check.sh` | Verify movie sync between sources |

### powershell/
Windows server and system administration.

| Script | Description |
|--------|-------------|
| `Install-ServerPrerequisites.ps1` | Install IIS, Web Deploy, URL Rewrite, SQL DAC |
| `UrlRewriteResources.ps1` | IIS URL Rewrite module setup |
| `VMAssignableDevice.ps1` | GPU passthrough for Hyper-V |
| `dotnet-install.ps1` | .NET Framework/Core installer |
| `Archive-ExtraOneDriveFolders.ps1` | Archive old OneDrive folders |
| `Zip-ExtraOneDriveFolders.ps1` | Compress OneDrive folders |

### sync/
File synchronization and Raspberry Pi backup.

| Script | Description |
|--------|-------------|
| `sync_folders.sh` | Bidirectional folder sync wrapper |
| `sync_folders_option1.py` | Python rsync wrapper (option 1) |
| `sync_folders_option2.py` | Python rsync wrapper (option 2) |
| `sync_archives.sh` | Bidirectional sync between external drives |
| `pi-to-synology-snapshot.sh` | Raspberry Pi to NAS snapshot backup |
| `pi-backup-prune.sh` | Prune old Pi snapshots |
| `pi-restore.sh` | Restore Pi from snapshots |
| `install-pi-synology-backup.sh` | Setup Pi-to-Synology backup system |

### system/
Linux/macOS system maintenance and monitoring.

| Script | Description |
|--------|-------------|
| `sysmaint.sh` | All-in-one server maintenance (APT, Docker, reboot) |
| `notify.py` | SMTP email notification sender |
| `welcome.sh` | Custom shell login welcome message with system stats |
| `bootstrap-motd.sh` | Normalize MOTD on Ubuntu (silence noise, keep useful info, idempotent) |

---

### Languages

| Language | Count |
|----------|-------|
| Bash | 40 |
| Python | 20 |
| PowerShell | 7 |

### Common Dependencies

| Tool | Used By |
|------|---------|
| rclone | backup/, sync/ |
| restic | backup/ |
| rsync | sync/ |
| docker | docker/, system/ |
| yt-dlp | downloaders/ |
| curl, jq | cloudflare/, immich/, dns/ |
| pandas | file-tools/ |

### License

MIT
