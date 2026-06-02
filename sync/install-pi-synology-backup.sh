#!/usr/bin/env bash
# install-pi-synology-backup.sh
# Installs backup scripts + systemd units; sets NAS config; offers to enable timer.
set -euo pipefail

# Defaults (can be overridden by flags)
NAS_HOST="kk-nas-002.local"
NAS_USER="backup"
NAS_BASE="/volume1/Data/pi-backups"
ENABLE_TIMER=false
DRY_RUN=false

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --nas-host=*) NAS_HOST="${arg#*=}";;
    --nas-user=*) NAS_USER="${arg#*=}";;
    --nas-base=*) NAS_BASE="${arg#*=}";;
    --enable-timer) ENABLE_TIMER=true;;
    --disable-timer) ENABLE_TIMER=false;;
    --dry-run) DRY_RUN=true;;
  esac
done

run_cmd() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

echo "==> Installing scripts to /usr/local/sbin ..."
run_cmd install -m 0755 "/opt/pi-synology/pi-to-synology-snapshot.sh" /usr/local/sbin/
run_cmd install -m 0755 "/opt/pi-synology/pi-backup-prune.sh" /usr/local/sbin/ || true
run_cmd install -m 0755 "/opt/pi-synology/pi-restore.sh" /usr/local/sbin/ || true

echo "==> Installing systemd units ..."
run_cmd install -D -m 0644 "/opt/pi-synology/systemd/pi-to-synology-snapshot.service" /etc/systemd/system/pi-to-synology-snapshot.service
run_cmd install -D -m 0644 "/opt/pi-synology/systemd/pi-to-synology-snapshot.timer"   /etc/systemd/system/pi-to-synology-snapshot.timer

if [[ "${DRY_RUN}" == "false" ]]; then
  echo "==> Applying NAS settings to backup script ..."
  sed -i "s|^NAS_HOST=.*|NAS_HOST=\"${NAS_HOST}\"|" /usr/local/sbin/pi-to-synology-snapshot.sh
  sed -i "s|^NAS_USER=.*|NAS_USER=\"${NAS_USER}\"|" /usr/local/sbin/pi-to-synology-snapshot.sh
  sed -i "s|^NAS_BASE=.*|NAS_BASE=\"${NAS_BASE}\"|" /usr/local/sbin/pi-to-synology-snapshot.sh
else
  echo "[dry-run] Would apply NAS settings: HOST=${NAS_HOST} USER=${NAS_USER} BASE=${NAS_BASE}"
fi

echo "==> Ensuring dependencies ..."
if [[ "${DRY_RUN}" == "false" ]]; then
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y rsync openssh-client >/dev/null 2>&1 || true
else
  echo "[dry-run] Would run: apt-get install -y rsync openssh-client"
fi

echo "==> Creating root SSH key if missing ..."
if [[ ! -f /root/.ssh/id_ed25519 ]]; then
  if [[ "${DRY_RUN}" == "false" ]]; then
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519
  else
    echo "[dry-run] Would generate /root/.ssh/id_ed25519"
  fi
fi

echo "==> Attempting to install key on NAS user ${NAS_USER}@${NAS_HOST} (you may be prompted once) ..."
if [[ "${DRY_RUN}" == "false" ]]; then
  ssh-copy-id -i /root/.ssh/id_ed25519.pub "${NAS_USER}@${NAS_HOST}" || echo ">> Could not install key automatically. Run: sudo -i; ssh-copy-id ${NAS_USER}@${NAS_HOST}"
else
  echo "[dry-run] Would run: ssh-copy-id -i /root/.ssh/id_ed25519.pub ${NAS_USER}@${NAS_HOST}"
fi

echo "==> Testing key auth ..."
if [[ "${DRY_RUN}" == "false" ]]; then
  if ssh -o BatchMode=yes "${NAS_USER}@${NAS_HOST}" 'echo key ok'; then
    echo "Key-based auth OK."
  else
    echo "WARNING: Key auth not ready. You can proceed, but rsync will fail until key is installed."
  fi
else
  echo "[dry-run] Would test SSH key auth to ${NAS_USER}@${NAS_HOST}"
fi

if $ENABLE_TIMER; then
  echo "==> Enabling nightly timer ..."
  if [[ "${DRY_RUN}" == "false" ]]; then
    systemctl daemon-reload
    systemctl enable --now pi-to-synology-snapshot.timer
    systemctl list-timers | grep synology || true
  else
    echo "[dry-run] Would enable pi-to-synology-snapshot.timer"
  fi
else
  echo "==> Timer not enabled (use --enable-timer to activate)."
fi

echo "==> Done. Next steps:"
echo "  1) Dry run: sudo /usr/local/sbin/pi-to-synology-snapshot.sh"
echo "  2) Real run: sudo sed -i 's/^DRY_RUN=true/DRY_RUN=false/' /usr/local/sbin/pi-to-synology-snapshot.sh && sudo /usr/local/sbin/pi-to-synology-snapshot.sh"
