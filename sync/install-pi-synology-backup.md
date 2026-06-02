# install-pi-synology-backup
## Michal Ferber
## Revised Date: 03/27/2026
### Description
An installer script for the Raspberry Pi to Synology NAS backup system. It copies the backup/prune/restore scripts into `/usr/local/sbin`, installs systemd service and timer units, configures the NAS connection details, installs dependencies (rsync, openssh-client), generates an SSH key if needed, and optionally enables the nightly backup timer.
### How to Use
```bash
# Preview what the installer would do (no changes made)
sudo ./install-pi-synology-backup.sh --dry-run

# Install with default NAS settings
sudo ./install-pi-synology-backup.sh

# Install with custom NAS settings
sudo ./install-pi-synology-backup.sh --nas-host=my-nas.local --nas-user=pibackup --nas-base=/volume1/backups

# Install and enable the nightly backup timer
sudo ./install-pi-synology-backup.sh --enable-timer
```
Prerequisites: Must be run as root. Expects scripts in `/opt/pi-synology/` and systemd unit files in `/opt/pi-synology/systemd/`.
### What and Where to Tweak
- `NAS_HOST` (line 7): Hostname or IP of the Synology NAS (or pass `--nas-host=`).
- `NAS_USER` (line 8): SSH user on the NAS (or pass `--nas-user=`).
- `NAS_BASE` (line 9): Base backup path on the NAS (or pass `--nas-base=`).
- Source script path `/opt/pi-synology/` (lines 35-37, 40-41): Change if your scripts live elsewhere.
- SSH key path `/root/.ssh/id_ed25519` (lines 60-64): Change if using a different key type or location.
