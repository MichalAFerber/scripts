#!/usr/bin/env bash
# pi-to-synology-snapshot.sh
# Incremental, timestamped rsync snapshots to Synology NAS.
# Each host writes to /volume1/Data/pi-backups/$HOSTNAME/<timestamp> on the NAS.
set -euo pipefail

##### === USER CONFIG === #####
NAS_HOST="kk-nas-002.local"          # Synology hostname or IP (e.g., 192.168.50.22)
NAS_USER="backup"                    # Synology user (must have R/W to the 'Data' share)
NAS_BASE="/volume1/Data/pi-backups"  # Base directory on the NAS filesystem
SSH_PORT=22                          # Change if you use a non-default SSH port
DRY_RUN=true                         # Safety first! Set to 'false' when ready.
PRESERVE_ONE_FS=true                 # true = stay on root FS only (skip mounted USBs, etc.)
DEBUG=false                          # true = verbose bash tracing

# Optional: throttle rsync (KB/s; 0 = unlimited)
BWLIMIT_KBPS=0

##### === DERIVED === #####
$DEBUG && set -x || true
HOSTNAME_SHORT="$(hostname -s)"
STAMP="$(date +%F_%H%M%S)"
REMOTE_HOST="${NAS_USER}@${NAS_HOST}"
REMOTE_HOST_BASE="${REMOTE_HOST}:${NAS_BASE}/${HOSTNAME_SHORT}"
REMOTE_SNAPSHOT="${REMOTE_HOST_BASE}/${STAMP}"

# Build rsync flags
RSYNC_FLAGS=(-aH --no-acls --no-xattrs --numeric-ids --delete --delete-excluded --partial --info=stats2,progress2)
[[ "${PRESERVE_ONE_FS}" == "true" ]] && RSYNC_FLAGS+=(-x)
(( BWLIMIT_KBPS > 0 )) && RSYNC_FLAGS+=(--bwlimit="${BWLIMIT_KBPS}")
[[ "${DRY_RUN}" == "true" ]] && RSYNC_FLAGS+=(--dry-run)

# SSH options (force key auth; no password prompts)
SSH_OPTS=(-p "${SSH_PORT}" -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -o PubkeyAuthentication=yes -o PasswordAuthentication=no -i /root/.ssh/id_ed25519)

# Ensure rsync uses the same SSH options
RSYNC_RSH="ssh ${SSH_OPTS[*]}"
RSYNC_REMOTE_PATH="--rsync-path=/usr/bin/rsync"

# Exclusions (exclude dirs and contents)
EXC_FILE="$(mktemp)"
trap 'rm -f "${EXC_FILE}"' EXIT
cat > "${EXC_FILE}" <<'EOF'
# virtual/kernel/runtime (exclude dir AND contents)
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

# caches & big volatile logs
/var/cache/**
/var/log/journal/*/*
/var/lib/apt/lists/**
/var/lib/systemd/coredump/**

# docker noise (comment out if you want everything)
/var/lib/docker/overlay2/**
/var/lib/docker/containers/*/*-json.log

# user caches
/home/*/.cache/**

# avoid recursion into other mounts under /Data (if ever present)
/Data/**

# Optional: skip large downloaded packages
/var/cache/apt/archives/*.deb
EOF

echo "==> Backing up host '${HOSTNAME_SHORT}' to ${REMOTE_SNAPSHOT}"
echo "==> NAS base: ${NAS_BASE}"
echo "==> DRY RUN: ${DRY_RUN}"

# Ensure base/host dir exists on NAS
ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" "mkdir -p ${NAS_BASE}/${HOSTNAME_SHORT}"

# Discover latest snapshot for --link-dest (hardlink de-duplication)
LATEST_REMOTE_DIR="$(ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" "ls -1dt ${NAS_BASE}/${HOSTNAME_SHORT}/*/ 2>/dev/null | head -n1 || true")"
if [[ -n "${LATEST_REMOTE_DIR}" ]]; then
  echo "==> Using --link-dest=${LATEST_REMOTE_DIR}"
  RSYNC_FLAGS+=(--link-dest="${LATEST_REMOTE_DIR%/}")
fi

# Create the new snapshot directory
ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" "mkdir -p ${NAS_BASE}/${HOSTNAME_SHORT}/${STAMP}"

# Run rsync from root (/) to snapshot dir
# Note: trailing slashes are important: source "/" -> destination "<snap>/".
sudo rsync "${RSYNC_FLAGS[@]}" \
  ${RSYNC_REMOTE_PATH} \
  -e "${RSYNC_RSH}" \
  --exclude-from="${EXC_FILE}" \
  / "${REMOTE_SNAPSHOT}/"

echo "==> Snapshot complete: ${REMOTE_SNAPSHOT}"
[[ "${DRY_RUN}" == "true" ]] && echo "==> (dry run only; no data was written)"

# Update a 'latest' symlink on NAS for convenience
ssh "${SSH_OPTS[@]}" "${REMOTE_HOST}" "
  cd ${NAS_BASE}/${HOSTNAME_SHORT} && \
  rm -f latest && \
  ln -s ${STAMP} latest
"
echo "==> Updated 'latest' symlink."
