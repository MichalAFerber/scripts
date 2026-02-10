# Backup Kit (3-2-1)

This kit packages a practical 3–2–1 backup workflow for macOS, Linux/Pi, and self‑hosted services.

**What you get**
- Ready-to-edit scripts (Bash) for:
  - macOS user-data → Restic (encrypted) on S3 via `rclone`
  - Linux/Pi offsite sync of your snapshot folder via `rclone`
  - Immich (Azure) nightly DB dump + uploads sync
  - GitHub organization/user **full mirror**
  - Nginx Proxy Manager (NPM) volume backup
- Example **systemd** units/timers for Linux
- Example **crontab** entry for macOS
- Starter excludes for macOS

## Quick Start

### 0) Prereqs
- `rclone` (configured with a remote named `wasabi-ferber`)  
- Optional encrypted remote wrapper: `wasabi-crypt` (type **crypt** wrapping `wasabi-ferber:ferber-storage`)
- `restic` (macOS backups)
- `gh` GitHub CLI (for repo mirroring)
- `postgresql-client` (for `pg_dump` used by Immich script)
- `jq` (used by the GitHub mirror script)
- (Docker hosts) `docker` available for NPM backup if you prefer container‑based tar

### 1) Configure your secrets
- **rclone crypt remote**:

  ```bash
  rclone config create wasabi-crypt crypt remote=wasabi-ferber:ferber-storage password=<pass> password2=<salt>
  ```

- **Restic password (macOS)**:

  ```bash
  security add-generic-password -a "$USER" -s restic-pass -w 'pick-a-strong-passphrase'
  ```

- **(Optional) Healthchecks.io**: set `HC_URL` env var in systemd environment or the shell before running scripts.

### 2) Edit variables at the top of each script
Every script has a **Variables** section. Adjust paths, remotes, and names to match your environment.

### 3) Schedule

**Linux/systemd**
```bash
sudo cp systemd/*.service systemd/*.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now immich-backup.timer linux-offsite-sync.timer
```

**macOS/cron** (example)
```bash
crontab cron/macos-restic-nightly.txt
```

### 4) Test restore (important!)
- Restic: `restic snapshots` then `restic restore <ID> --target ~/RestoreTest`
- rclone: `rclone copy wasabi-crypt:immich/pg ./restore-test/pg`
- Verify files open and DB dumps restore with `pg_restore -l`.

## Disaster Recovery Notes
- **macOS**: Reinstall → Time Machine → use Restic to catch up deltas.
- **Immich**: Recreate VM → docker compose up → restore DB from dump → sync `uploads/`.
- **Plex**: restore Plex DB folder from NAS snapshot; media is covered locally on two copies.

## Structure
```
backup-kit/
  README.md
  scripts/
    macos-restic-backup.sh
    linux-offsite-sync.sh
    immich-backup.sh
    github-mirror.sh
    npm-backup.sh
  systemd/
    *.service, *.timer
  cron/
    macos-restic-nightly.txt
  examples/
    excludes-macos.txt
```

> All scripts are **idempotent** and safe to run repeatedly. Logs go to `/var/log` or `~/Logs` by default (see variables).
