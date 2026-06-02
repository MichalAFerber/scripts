# sysmaint
## Michal Ferber
## Revised Date: 03/27/2026
### Description
All-in-one server maintenance script for Debian/Ubuntu hosts with Docker. It updates and upgrades APT packages, pulls and restarts Docker Compose projects and standalone containers, prunes unused Docker images and build cache, displays a system report (disk, memory, Docker disk usage), and optionally reboots the server if needed. Sends email notifications on completion via the companion notify.py script. Can be run interactively through a menu or non-interactively with the --all flag.
### How to Use
```bash
# Interactive menu
sudo ./sysmaint.sh

# Run all steps non-interactively, auto-confirm prompts
sudo ./sysmaint.sh --all --yes

# Run all steps with auto-reboot if the kernel requires it
sudo ./sysmaint.sh --all --yes --reboot-if-needed

# Preview what would happen without making changes
sudo ./sysmaint.sh --all --dry-run

# Use a custom config file for email notifications
sudo ./sysmaint.sh --all --yes --config /path/to/config.json
```

**Flags:**
- `--all` — Run all maintenance steps non-interactively
- `-y` / `--yes` — Auto-confirm all prompts
- `--reboot-if-needed` — Reboot automatically if the system requires it
- `--config PATH` — Path to config.json (for SMTP/email notifications)
- `--log-dir DIR` — Custom log directory (default: `~/.local/share/sysmaint/logs`)
- `--dry-run` — Print commands instead of executing them
- `-h` / `--help` — Show help

**Prerequisites:** bash 4+, sudo/root access, Docker (optional), python3 + notify.py (optional, for email notifications).
### What and Where to Tweak
- **CONFIG_PATH** — Set via `SYSMAINT_CONFIG` env var or `--config` flag; defaults to `config.json` in the script directory. Must contain SMTP credentials and notification recipients for email to work.
- **LOG_DIR** — Set via `SYSMAINT_LOG_DIR` env var or `--log-dir` flag; defaults to `~/.local/share/sysmaint/logs`.
- **REBOOT_IF_NEEDED** — Set to `1` via env var or `--reboot-if-needed` flag to auto-reboot.
- **Docker volume pruning** — Disabled by default. Uncomment the `docker volume prune` line in the `prune_docker` function if you want to remove unused volumes.
- **notify.py** — Place in the same directory as sysmaint.sh for email notifications to work.
