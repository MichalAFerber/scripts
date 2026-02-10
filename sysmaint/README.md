# SysMaint — All-in-one Server Maintenance Toolkit

**What it does**
- APT: `update`, `upgrade`, `full-upgrade`, `autoremove`, `autoclean`
- Docker: updates compose projects (pull + up -d), refreshes standalone containers, optional prune
- Restarts running containers
- Reboot check (auto-reboot optional)
- One combined log + a separate error log for every run
- Email notification via SMTP (success summary or error report)
- Interactive menu **or** non-interactive flags for cron

## Files
```
sysmaint/
├─ sysmaint.sh     # main script
├─ notify.py       # SMTP email sender
├─ config.json     # edit with your SMTP + recipients
└─ README.md
```

Logs are written to `${SYSMAINT_LOG_DIR:-$HOME/.local/share/sysmaint/logs}` by default (created if missing).

## Install
```bash
# Copy somewhere, e.g. /opt/sysmaint
sudo mkdir -p /opt/sysmaint
sudo cp -a sysmaint/* /opt/sysmaint/
sudo chmod 755 /opt/sysmaint/sysmaint.sh
sudo chown -R root:root /opt/sysmaint

# Optional: put on PATH
sudo ln -sf /opt/sysmaint/sysmaint.sh /usr/local/sbin/sysmaint
```

## Configure SMTP
Edit `/opt/sysmaint/config.json`:
```json
{
  "smtp": {
    "host": "smtp.example.com",
    "port": 587,
    "username": "user@example.com",
    "password": "APP_PASSWORD_HERE",
    "starttls": true,
    "from": "sysmaint@example.com"
  },
  "notify": {
    "to": [
      "you@example.com"
    ],
    "subject_prefix": "[SysMaint]"
  }
}
```

> Use an app-specific password if your provider requires it.

## Run (interactive)
```bash
sudo /opt/sysmaint/sysmaint.sh
# or
sudo sysmaint
```

## Run (non-interactive)
```bash
# All steps, auto-yes, auto-reboot if needed:
sudo /opt/sysmaint/sysmaint.sh --all --yes --reboot-if-needed
```

## Cron
Open root's crontab:
```bash
sudo crontab -e
```
Example (Sundays 03:15):
```
15 3 * * 0 SYSMAINT_LOG_DIR=/var/log/sysmaint /opt/sysmaint/sysmaint.sh --all --yes --reboot-if-needed
```

## Notes & Safety
- Designed for Debian/Ubuntu hosts with Docker. APT requires root.
- Compose discovery uses `docker compose ls`; falls back gracefully.
- Standalone container refresh pulls images and restarts containers to adopt newer tags.
- `docker image prune -af` removes unused images only (not containers). Volume prune is **disabled** by default; enable inside the script if you want it.

## Troubleshooting
- **No emails?** Ensure Python 3 is installed and `config.json` is correct.
- **No compose projects found?** Some older Docker setups don't expose `compose ls`; run the update from each compose project folder.
- **Permissions on logs:** set `SYSMAINT_LOG_DIR` to a user-writable dir if not running as root.

## Make it better
- Add per-host config for include/exclude lists of compose projects.
- Emit Prometheus-friendly metrics file; scrape with node_exporter textfile collector.
- Add a `--dry-run` flag to preview actions.
- Integrate with `unattended-upgrades` for automatic security patches.
- Add pre/post hooks for backups or service drain notifications.
