#!/usr/bin/env bash
set -euo pipefail
BASE_URL="https://raw.githubusercontent.com/USER/REPO/BRANCH"
NAS_HOST="kk-nas-001.local"
NAS_USER="backup"
NAS_BASE="/volume1/Data/pi-backups"
ENABLE_TIMER=false
ENABLE_PRUNE=false
PRUNE_KEEP=14
SET_DRY_RUN=""
usage(){ cat <<EOF
Usage: netinstall ... --base-url=https://raw.githubusercontent.com/<USER>/<REPO>/<BRANCH> [flags]
  --nas-host=HOST            (default: ${NAS_HOST})
  --nas-user=USER            (default: ${NAS_USER})
  --nas-base=PATH            (default: ${NAS_BASE})
  --enable-timer|--disable-timer
  --enable-prune|--disable-prune
  --prune-keep=N             (default: ${PRUNE_KEEP})
  --set-dry-run=true|false
EOF
}
for arg in "$@"; do
  case "$arg" in
    --base-url=*) BASE_URL="${arg#*=}";;
    --nas-host=*) NAS_HOST="${arg#*=}";;
    --nas-user=*) NAS_USER="${arg#*=}";;
    --nas-base=*) NAS_BASE="${arg#*=}";;
    --enable-timer) ENABLE_TIMER=true;;
    --disable-timer) ENABLE_TIMER=false;;
    --enable-prune) ENABLE_PRUNE=true;;
    --disable-prune) ENABLE_PRUNE=false;;
    --prune-keep=*) PRUNE_KEEP="${arg#*=}";;
    --set-dry-run=*) SET_DRY_RUN="${arg#*=}";;
    -h|--help) usage; exit 0;;
    *) echo "Unknown flag: $arg"; usage; exit 1;;
  esac
done
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y curl rsync openssh-client ca-certificates >/dev/null 2>&1 || true
INSTALL_ROOT="/opt/pi-synology"; mkdir -p "${INSTALL_ROOT}" "${INSTALL_ROOT}/systemd"
fetch(){ curl -fsSL "${BASE_URL%/}/$1" -o "$2"; }
fetch pi-to-synology-snapshot.sh            "${INSTALL_ROOT}/pi-to-synology-snapshot.sh"
fetch pi-backup-prune.sh                    "${INSTALL_ROOT}/pi-backup-prune.sh"
fetch pi-restore.sh                         "${INSTALL_ROOT}/pi-restore.sh"
fetch systemd/pi-to-synology-snapshot.service "${INSTALL_ROOT}/systemd/pi-to-synology-snapshot.service"
fetch systemd/pi-to-synology-snapshot.timer   "${INSTALL_ROOT}/systemd/pi-to-synology-snapshot.timer"
fetch systemd/pi-backup-prune.service       "${INSTALL_ROOT}/systemd/pi-backup-prune.service"
fetch systemd/pi-backup-prune.timer         "${INSTALL_ROOT}/systemd/pi-backup-prune.timer"
install -m 0755 "${INSTALL_ROOT}/pi-to-synology-snapshot.sh" /usr/local/sbin/
install -m 0755 "${INSTALL_ROOT}/pi-backup-prune.sh" /usr/local/sbin/
install -m 0755 "${INSTALL_ROOT}/pi-restore.sh" /usr/local/sbin/
install -D -m 0644 "${INSTALL_ROOT}/systemd/pi-to-synology-snapshot.service" /etc/systemd/system/pi-to-synology-snapshot.service
install -D -m 0644 "${INSTALL_ROOT}/systemd/pi-to-synology-snapshot.timer" /etc/systemd/system/pi-to-synology-snapshot.timer
install -D -m 0644 "${INSTALL_ROOT}/systemd/pi-backup-prune.service" /etc/systemd/system/pi-backup-prune.service
install -D -m 0644 "${INSTALL_ROOT}/systemd/pi-backup-prune.timer" /etc/systemd/system/pi-backup-prune.timer
sed -i "s|^NAS_HOST=.*|NAS_HOST=\"${NAS_HOST}\"|" /usr/local/sbin/pi-to-synology-snapshot.sh
sed -i "s|^NAS_USER=.*|NAS_USER=\"${NAS_USER}\"|" /usr/local/sbin/pi-to-synology-snapshot.sh
sed -i "s|^NAS_BASE=.*|NAS_BASE=\"${NAS_BASE}\"|" /usr/local/sbin/pi-to-synology-snapshot.sh
sed -i "s|@KEEP@|${PRUNE_KEEP}|" /etc/systemd/system/pi-backup-prune.service
if [[ -n "${SET_DRY_RUN}" ]]; then sed -i "s/^DRY_RUN=.*/DRY_RUN=${SET_DRY_RUN}/" /usr/local/sbin/pi-to-synology-snapshot.sh; fi
if [[ ! -f /root/.ssh/id_ed25519 ]]; then mkdir -p /root/.ssh && chmod 700 /root/.ssh && ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519; fi
ssh-copy-id -i /root/.ssh/id_ed25519.pub "${NAS_USER}@${NAS_HOST}" || true
systemctl daemon-reload
[[ "$ENABLE_TIMER" == "true" ]] && systemctl enable --now pi-to-synology-snapshot.timer || true
[[ "$ENABLE_PRUNE" == "true" ]] && systemctl enable --now pi-backup-prune.timer || true
echo "Installed. Run: sudo /usr/local/sbin/pi-to-synology-snapshot.sh"
