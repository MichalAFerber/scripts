# pi-restore
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Restores files or directories from a Pi backup snapshot stored on a Synology NAS. Can restore from a specific timestamped snapshot or from the `latest` symlink. When restoring a directory, it mirrors the snapshot exactly (using `--delete`). When restoring a single file, it copies just that file.
### How to Use
```bash
# Preview a restore without making changes
sudo ./pi-restore.sh --dry-run latest /etc/ /tmp/restore-etc/

# Restore a directory from the latest snapshot
sudo ./pi-restore.sh latest /etc/ /tmp/restore-etc/

# Restore a single file from a specific snapshot
sudo ./pi-restore.sh 2025-08-17_100213 /etc/hostname /tmp/hostname.restored

# Restore everything from latest to / (full restore)
sudo ./pi-restore.sh latest / /
```
Prerequisites: SSH key-based auth for `backup@kk-nas-002.local` at `/root/.ssh/id_ed25519`. Must run as root (via sudo).
### What and Where to Tweak
- NAS connection string `backup@kk-nas-002.local` (lines 30, 34): Change to match your NAS hostname and user.
- NAS backup path `/volume1/Data/pi-backups` (line 20): Adjust if backups are stored elsewhere.
- SSH key path `/root/.ssh/id_ed25519` (line 22): Change if using a different key.
