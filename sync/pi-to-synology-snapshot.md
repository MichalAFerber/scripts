# pi-to-synology-snapshot
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Creates an incremental snapshot backup of a Raspberry Pi's entire filesystem to a Synology NAS over SSH using rsync. Each run creates a new timestamped directory on the NAS, using `--link-dest` to hard-link unchanged files against the previous snapshot (saving disk space). A `latest` symlink is updated on each successful run. Dry-run mode is enabled by default.
### How to Use
```bash
# Run in dry-run mode (default) -- shows what would be transferred
sudo ./pi-to-synology-snapshot.sh

# Run for real -- edit the script to set DRY_RUN=false first
sudo sed -i 's/^DRY_RUN=true/DRY_RUN=false/' pi-to-synology-snapshot.sh
sudo ./pi-to-synology-snapshot.sh
```
Prerequisites: rsync, SSH key-based auth set up for the NAS user (`/root/.ssh/id_ed25519`), and the NAS must be reachable.
### What and Where to Tweak
- `NAS_HOST` (line 5): Hostname or IP of the Synology NAS.
- `NAS_USER` (line 6): SSH user on the NAS with write access to the backup share.
- `NAS_BASE` (line 7): Base path on the NAS where backups are stored.
- `SSH_PORT` (line 8): SSH port if non-standard.
- `DRY_RUN` (line 9): Set to `false` to perform real backups.
- `PRESERVE_ONE_FS` (line 10): Set to `false` to cross filesystem boundaries.
- `BWLIMIT_KBPS` (line 12): Set to a positive number to throttle bandwidth (KB/s).
- The exclude list (lines 32-60): Add or remove paths that should be skipped during backup.
