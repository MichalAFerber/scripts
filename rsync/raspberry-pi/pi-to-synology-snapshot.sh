#!/usr/bin/env bash
set -euo pipefail

##### === USER CONFIG === #####
NAS_HOST="kk-nas-001.local"
NAS_USER="backup"
NAS_BASE="/volume1/Data/pi-backups"
SSH_PORT=22
DRY_RUN=true
PRESERVE_ONE_FS=true
DEBUG=false
BWLIMIT_KBPS=0

##### === DERIVED === #####
$DEBUG && set -x || true
HOSTNAME_SHORT="$(hostname -s)"
STAMP="$(date +%F_%H%M%S)"
REMOTE_HOST="${NAS_USER}@${NAS_HOST}"
REMOTE_HOST_BASE="${REMOTE_HOST}:${NAS_BASE}/${HOSTNAME_SHORT}"
REMOTE_SNAPSHOT="${REMOTE_HOST_BASE}/${STAMP}"

RSYNC_FLAGS=(-aH --no-acls --no-xattrs --numeric-ids --delete --delete-excluded --partial --info=stats2,progress2)
[[ "${PRESERVE_ONE_FS}" == "true" ]] && RSYNC_FLAGS+=(-x)
(( BWLIMIT_KBPS > 0 )) && RSYNC_FLAGS+=(--bwlimit="${BWLIMIT_KBPS}")
[[ "${DRY_RUN}" == "true" ]] && RSYNC_FLAGS+=(--dry-run)

SSH_OPTS=(-p "${SSH_PORT}" -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -o PubkeyAuthentication=yes -o PasswordAuthentication=no -i /root/.ssh/id_ed25519)
RSYNC_RSH="ssh ${SSH_OPTS[*]}"
RSYNC_REMOTE_PATH="--rsync-path=/usr/bin/rsync"

EXC_FILE="$(mktemp)"; trap 'rm -f "${EXC_FILE}"' EXIT
cat > "${EXC_FILE}" <<'EOF'
/proc
/sys
/run
/dev
/tmp
/mnt
/media
/lost+found
/var/tmp
/proc/**
/sys/**
/run/**
/dev/**
/tmp/**
/mnt/**
/media/**
/lost+found/**
/var/tmp/**
/var/cache/**
/var/log/journal/*/*
/var/lib/apt/lists/**
/var/lib/systemd/coredump/**
/var/lib/docker/overlay2/**
/var/lib/docker/containers/*/*-json.log
/home/*/.cache/**
/Data/**
/var/cache/apt/archives/*.deb
EOF

echo "==> Backing up host '${HOSTNAME_SHORT}' to ${REMOTE_SNAPSHOT}"
echo "==> NAS base: ${NAS_BASE}"
echo "==> DRY RUN: ${DRY_RUN}"

ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" "mkdir -p ${NAS_BASE}/${HOSTNAME_SHORT}"
LATEST_REMOTE_DIR="$(ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" "ls -1dt ${NAS_BASE}/${HOSTNAME_SHORT}/*/ 2>/dev/null | head -n1 || true")"
if [[ -n "${LATEST_REMOTE_DIR}" ]]; then
  echo "==> Using --link-dest=${LATEST_REMOTE_DIR}"
  RSYNC_FLAGS+=(--link-dest="${LATEST_REMOTE_DIR%/}")
fi
ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" "mkdir -p ${NAS_BASE}/${HOSTNAME_SHORT}/${STAMP}"

sudo rsync "${RSYNC_FLAGS[@]}" ${RSYNC_REMOTE_PATH} -e "${RSYNC_RSH}" --exclude-from="${EXC_FILE}" / "${REMOTE_SNAPSHOT}/"

echo "==> Snapshot complete: ${REMOTE_SNAPSHOT}"
[[ "${DRY_RUN}" == "true" ]] && echo "==> (dry run only; no data was written)"
ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" "cd ${NAS_BASE}/${HOSTNAME_SHORT} && rm -f latest && ln -s ${STAMP} latest"
echo "==> Updated 'latest' symlink."
