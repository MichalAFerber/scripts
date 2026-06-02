# migrate-nas-snapshots
## Michal Ferber
## Revised Date: 06/02/2026
### Description
NAS-to-NAS rsync helper for moving Pi backup snapshots between two Synology hosts. Runs the rsync **from the destination NAS** so it pulls from the source — useful when migrating to new NAS hardware or building a redundant secondary.

### How to Use

```bash
# Defaults: src = kk-nas-002.local, dst = kk-nas-001.local, user = backup, base = /volume1/Data/pi-backups
./migrate-nas-snapshots.sh

# Override defaults
./migrate-nas-snapshots.sh kk-nas-old.local kk-nas-new.local backup /volume1/Data/pi-backups /volume1/Data/pi-backups
```

### Positional args (in order)

| Position | Default | Meaning |
|---|---|---|
| 1 | `kk-nas-002.local` | Source NAS hostname |
| 2 | `kk-nas-001.local` | Destination NAS hostname |
| 3 | `backup` | SSH user on both NAS hosts |
| 4 | `/volume1/Data/pi-backups` | Source base path |
| 5 | `/volume1/Data/pi-backups` | Destination base path |

### What it does

1. SSH into the destination NAS
2. `mkdir -p` the destination path
3. Run `rsync -aH --numeric-ids --no-acls --no-xattrs --delete --info=progress2` pulling from source over SSH

Mirroring with `--delete` — anything not on source gets removed on destination.

### Requirements

- SSH access (key-based) to both NAS hosts as the named user
- rsync on both NAS hosts (Synology DSM ships with it)

### Pairs with

- [`pi-to-synology-snapshot.sh`](pi-to-synology-snapshot.md) — Pi → NAS snapshot
- [`netinstall-pi-synology-backup.sh`](netinstall-pi-synology-backup.md) — installer
