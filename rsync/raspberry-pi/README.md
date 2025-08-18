# Pi → Synology Snapshot Backups (rsync + SSH)

Back up any Raspberry Pi to a Synology NAS as **timestamped, de‑duplicated snapshots** using `rsync` over SSH. Each host writes to:

```bash
/volume1/Data/pi-backups/<hostname>/<YYYY-MM-DD_HHMMSS>/
/volume1/Data/pi-backups/<hostname>/latest -> <latest snapshot>
```

- Space‑efficient snapshots via `--link-dest` (hard‑links for unchanged files).
- Safe defaults: `DRY_RUN=true` until you flip it.
- Clean excludes so you don’t copy `/proc`, `/sys`, caches, etc.
- Key‑based SSH from **Pi root** → NAS for unattended runs.
- Includes optional prune (retention), restore helper, and a systemd timer.
- An installer script is provided to set everything up quickly.

---

## Quick Start (TL;DR)

```bash
# copy package to Pi and unzip
scp pi-synology-backups-package.zip pi@<pi-host>:/tmp/
ssh pi@<pi-host> 'sudo apt-get update && sudo apt-get install -y rsync openssh-client && sudo mkdir -p /opt/pi-synology && unzip -o /tmp/pi-synology-backups-package.zip -d /opt/pi-synology'

# run installer (edit values or pass flags)
ssh pi@<pi-host> 'sudo bash /opt/pi-synology/install-pi-synology-backup.sh --nas-host=kk-nas-002.local --nas-user=backup --nas-base=/volume1/Data/pi-backups --enable-timer'
```

Then:

```bash
# first dry run
sudo /usr/local/sbin/pi-to-synology-snapshot.sh
# flip to real
sudo sed -i 's/^DRY_RUN=true/DRY_RUN=false/' /usr/local/sbin/pi-to-synology-snapshot.sh
sudo /usr/local/sbin/pi-to-synology-snapshot.sh
```

---

## What’s inside

- `pi-to-synology-snapshot.sh` – main backup script (rsync + SSH, `--link-dest`)
- `pi-backup-prune.sh` – keep only last N snapshots for this host
- `pi-restore.sh` – restore a file or directory from any snapshot
- `systemd/pi-to-synology-snapshot.service` – systemd service wrapper
- `systemd/pi-to-synology-snapshot.timer` – nightly timer (02:30)
- `install-pi-synology-backup.sh` – one-shot installer for the above
- `README-pi-synology-backups.md` – this guide

---

## 0) Synology requirements

- **SSH enabled**: Control Panel → *Terminal & SNMP* → Enable SSH.
- **User**: a non-admin user (e.g., `backup`) with **Read/Write** to the `Data` share.
- rsync present at `/usr/bin/rsync` (default on DSM).

---

## 1) Root SSH key on each Pi (for unattended runs)

```bash
sudo -i
ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519
ssh-copy-id backup@kk-nas-002.local
ssh backup@kk-nas-002.local 'echo key ok'   # should NOT prompt password
exit
```

(If you see a home-dir warning, it’s harmless. Enable *User Home service* to silence it.)

---

## 2) Scheduling (systemd)

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pi-to-synology-snapshot.timer
systemctl list-timers | grep synology
journalctl -u pi-to-synology-snapshot.service -n 200 --no-pager
```

---

## 3) Retention (optional)

```bash
sudo /usr/local/sbin/pi-backup-prune.sh 14   # keep last 14 snapshots
```

Schedule weekly if desired with another timer.

---

## 4) Restore examples

```bash
# restore a whole tree to /tmp/restore-etc/
sudo /usr/local/sbin/pi-restore.sh latest /etc/ /tmp/restore-etc/

# restore a single file to /tmp/
sudo /usr/local/sbin/pi-restore.sh latest /etc/hostname /tmp/hostname.restored
```

---

## 5) Using on other Pis

1. Copy this package, unzip under `/opt/pi-synology/`.
2. Run the installer with your NAS settings.
3. Generate a root SSH key and `ssh-copy-id` it to the NAS.
4. Dry-run, flip `DRY_RUN=false`, real run.
5. Enable the systemd timer.

That’s it. Every Pi will write to its own folder (by hostname).
