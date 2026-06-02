# netinstall-pi-synology-backup
## Michal Ferber
## Revised Date: 06/02/2026
### Description
One-liner net installer that fetches the Pi → Synology backup scripts (snapshot + prune + restore) and matching systemd units from this repo's raw URLs, installs them to standard locations, sets up the SSH key for the Pi → NAS rsync user, and optionally enables the systemd timer.

### How to Use

```bash
curl -fsSL https://raw.githubusercontent.com/MichalAFerber/scripts/main/sync/netinstall-pi-synology-backup.sh \
  | sudo bash -s -- \
  --base-url=https://raw.githubusercontent.com/MichalAFerber/scripts/main/sync \
  --nas-host=kk-nas-002.local \
  --nas-user=backup \
  --nas-base=/volume1/Data/pi-backups \
  --enable-timer \
  --set-dry-run=false
```

### Flags

| Flag | Description |
|---|---|
| `--base-url=URL` | Base URL to fetch the script files from (raw GitHub URL) |
| `--nas-host=HOST` | NAS hostname (default `kk-nas-002.local`) |
| `--nas-user=USER` | SSH user on the NAS (default `backup`) |
| `--nas-base=PATH` | Destination root on the NAS (default `/volume1/Data/pi-backups`) |
| `--enable-timer` | Enable the systemd timer for nightly 02:30 runs |
| `--set-dry-run=true\|false` | Toggle dry-run mode at install time |

### What it installs

- `pi-to-synology-snapshot.sh` → `/usr/local/sbin/`
- `pi-backup-prune.sh` → `/usr/local/sbin/`
- `pi-restore.sh` → `/usr/local/sbin/`
- `systemd/pi-to-synology-snapshot.service` → `/etc/systemd/system/`
- `systemd/pi-to-synology-snapshot.timer` → `/etc/systemd/system/`

Plus:

- Ensures `curl`, `rsync`, `openssh-client` are present
- Creates a root SSH key if missing and runs `ssh-copy-id` to the NAS

### Pairs with

- [`pi-to-synology-snapshot.sh`](pi-to-synology-snapshot.md) — the actual snapshot script
- [`pi-backup-prune.sh`](pi-backup-prune.md) — retention pruner
- [`pi-restore.sh`](pi-restore.md) — restore from snapshot
- [`migrate-nas-snapshots.sh`](migrate-nas-snapshots.md) — move snapshots NAS → NAS
