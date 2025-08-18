# Pi / Linux → NAS Snapshot Backups (rsync + SSH)

Back up any Raspberry Pi or Linux host to a NAS/remote Linux box over SSH as **timestamped, de-duplicated snapshots**. Each run creates:

```bash
/volume1/Data/pi-backups/<hostname>/<YYYY-MM-DD_HHMMSS>/
latest -> <most recent snapshot>
```

- Space-efficient: uses `rsync --link-dest` (hard-links unchanged files).
- Safe defaults (`DRY_RUN=true`) until you flip it.
- Clean excludes (no `/proc`, `/sys`, caches, etc.).
- Runs with key-based SSH from **root on the Pi/Linux host** → NAS.
- Optional: nightly schedule (systemd), retention (prune), and restore helper.

> Although examples mention Synology (DSM), this works with **any SSH-accessible Linux server** that has `rsync`. Just set `NAS_HOST`, `NAS_USER`, and `NAS_BASE` accordingly and ensure `rsync` exists (e.g., `/usr/bin/rsync`) on the remote.

---

## Files in this repo

- `pi-to-synology-snapshot.sh` — main backup script  
- `pi-backup-prune.sh` — (optional) keep only the last N snapshots  
- `pi-restore.sh` — (optional) restore a file or directory from a snapshot  
- `systemd/pi-to-synology-snapshot.service` — systemd unit  
- `systemd/pi-to-synology-snapshot.timer` — nightly timer (02:30)  
- `install-pi-synology-backup.sh` — one-shot installer  
- `README.md` — this guide

---

## Requirements

### On the NAS / remote target

- SSH enabled and reachable (e.g., `kk-nas-002.local` or an IP).
- A user (e.g., `backup`) with **read/write** permissions to the target folder/share.
- `rsync` installed (on Synology DSM it’s typically `/usr/bin/rsync`).

### On the Pi / Linux source

- `rsync`, `openssh-client`, `sudo` (usually preinstalled on Raspberry Pi OS / Debian).
- Ability to run the backup script with `sudo` (it backs up `/`).

---

## 1) Install the backup script

Copy the script to the machine you want to back up and install it:

```bash
sudo install -m 0755 pi-to-synology-snapshot.sh /usr/local/sbin/
```

Open the script and confirm these settings near the top:

```bash
NAS_HOST="kk-nas-002.local"          # or an IP (e.g., 192.168.50.22)
NAS_USER="backup"                    # user on the NAS/remote
NAS_BASE="/volume1/Data/pi-backups"  # base path on the remote
DRY_RUN=true                         # flip to false after validation
```

> For non-Synology remotes, set `NAS_BASE` to any directory your user can write, e.g., `/srv/backups/pi`.

---

## 2) Create a **root** SSH key and install it on the NAS

Because the script runs with `sudo`, it uses **root’s** SSH identity on the Pi/Linux host.

```bash
# become root
sudo -i

# generate a key (no passphrase)
ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519

# install the key on the remote user account
ssh-copy-id backup@kk-nas-002.local

# verify key-only auth (no password prompt)
ssh backup@kk-nas-002.local 'echo key ok'
exit
```

> On Synology, a “Could not chdir to /var/services/homes/backup” warning is harmless. Enable **User Home service** in DSM to silence it.

---

## 3) First run (dry → real)

```bash
# dry run (won’t write data)
sudo /usr/local/sbin/pi-to-synology-snapshot.sh

# flip to real
sudo sed -i 's/^DRY_RUN=true/DRY_RUN=false/' /usr/local/sbin/pi-to-synology-snapshot.sh

# real snapshot
sudo /usr/local/sbin/pi-to-synology-snapshot.sh
```

You should see a new dated folder under:

```bash
<NAS_BASE>/<hostname>/<YYYY-MM-DD_HHMMSS>/
latest -> that folder
```

---

## 4) What gets backed up (and why)

The script calls `rsync` with:

- `-aH --no-acls --no-xattrs --numeric-ids` (portable, avoids DSM xattr/ACL issues)
- An **exclude list** that skips:
  - Pseudo-filesystems: `/proc`, `/sys`, `/run`, `/dev`, `/tmp`, `/mnt`, `/media`, `/lost+found`, `/var/tmp`
  - Caches/log floods: `/var/cache/**`, `journal`, `apt lists`, `systemd coredumps`
  - Docker overlays/logs (comment out if you want them)
  - User cache: `/home/*/.cache/**`
  - `/Data/**` to avoid recursing into other mounts you might create later

Uncomment/tweak excludes to your liking.

---

## 5) Nightly schedule (systemd)

Install units:

```bash
sudo install -D -m 0644 systemd/pi-to-synology-snapshot.service /etc/systemd/system/pi-to-synology-snapshot.service
sudo install -D -m 0644 systemd/pi-to-synology-snapshot.timer   /etc/systemd/system/pi-to-synology-snapshot.timer

sudo systemctl daemon-reload
sudo systemctl enable --now pi-to-synology-snapshot.timer
systemctl list-timers | grep synology
# Logs:
journalctl -u pi-to-synology-snapshot.service -n 200 --no-pager
```

The timer runs daily at **02:30** with a small randomized delay.

---

## 6) Retention (prune old snapshots, optional)

Keep only the **last N** snapshots (default 14). This runs from the Pi/Linux host but deletes on the NAS via SSH:

```bash
sudo install -m 0755 pi-backup-prune.sh /usr/local/sbin/
sudo /usr/local/sbin/pi-backup-prune.sh 14
```

You can schedule this weekly with another systemd timer if desired.

---

## 7) Restore (file or directory)

Install the helper:

```bash
sudo install -m 0755 pi-restore.sh /usr/local/sbin/
```

Examples:

```bash
# restore a whole tree to /tmp/restore-etc/
sudo /usr/local/sbin/pi-restore.sh latest /etc/ /tmp/restore-etc/

# restore a single file
sudo /usr/local/sbin/pi-restore.sh latest /etc/hostname /tmp/hostname.restored
```

> For full system restore to `/`, you’ll typically boot from a rescue/live OS or another device and rsync back into the target root.

---

## 8) Using on other Pis / Linux hosts

1. Copy scripts to the host and install as above.  
2. Generate **root** SSH key and `ssh-copy-id` it to the NAS user (once per host).  
3. Dry run, flip `DRY_RUN=false`, real run.  
4. Enable the systemd timer.

Every machine automatically writes to its own folder named by **hostname**.

---

## 9) Troubleshooting

- **`Permission denied (publickey,password)` during rsync**  
  The nested SSH from rsync isn’t using your key. This repo’s script forces:

  ```bash
  -i /root/.ssh/id_ed25519 -o IdentitiesOnly=yes -o PubkeyAuthentication=yes -o PasswordAuthentication=no
  ```

  Re-run step 2 and re-test:

  ```bash
  sudo ssh backup@kk-nas-002.local 'echo key ok'
  ```

- **Exit code 23 with `set_xattr_acl` errors**  
  Ensure the script uses `-aH --no-acls --no-xattrs` and the pseudo-fs excludes above.

- **Empty timestamp folders**  
  Means mkdir on NAS succeeded but rsync failed; check SSH key usage and logs.

- **Name resolution issues**  
  Use the NAS **IP** instead of `*.local`.

- **Auto-block on DSM**  
  DSM → Control Panel → Security → Protection → Auto Block → remove your IP from the block list if needed.

---

## 10) Security tips

- The `backup` user only needs R/W to the designated share/folder (no admin).  
- Protect `/root/.ssh` and the private key (`chmod 700` and `chmod 600`).  
- Consider quotas/alerts on the NAS and test restores periodically.

---

## 11) Uninstall / disable

```bash
sudo systemctl disable --now pi-to-synology-snapshot.timer
sudo rm -f /etc/systemd/system/pi-to-synology-snapshot.{service,timer}
sudo systemctl daemon-reload

sudo rm -f /usr/local/sbin/pi-to-synology-snapshot.sh \
            /usr/local/sbin/pi-backup-prune.sh \
            /usr/local/sbin/pi-restore.sh
```

---

### FAQ

**Q: Can I back up to a non-Synology Linux server?**  
A: Yes. Ensure the remote has `rsync`, an SSH user with write access, and update `NAS_HOST`/`NAS_BASE`. The script already sets `--rsync-path=/usr/bin/rsync`.

**Q: Can I throttle bandwidth?**  
A: Set `BWLIMIT_KBPS` near the top of the script (e.g., `BWLIMIT_KBPS=5000` for ~5 MB/s).

**Q: Can I include mounted USB disks?**  
A: Set `PRESERVE_ONE_FS=false` (remove `-x`) and adjust excludes so you don’t recurse into mounts you don’t want.

**Q: Can I skip `latest` symlink?**  
A: Comment out the final `ln -s` lines in the script.

---

Happy backups ✨
