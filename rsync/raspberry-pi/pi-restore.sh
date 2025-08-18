#!/usr/bin/env bash
# Restore a file or directory from a chosen snapshot (or 'latest').
# Usage:
#   sudo pi-restore.sh latest /etc/ /tmp/restore-etc/
#   sudo pi-restore.sh 2025-08-17_100213 /etc/hostname /tmp/hostname.restored
set -euo pipefail
SNAP="${1:-latest}"
SRC="${2:-/}"
DEST="${3:-/}"
HOST="$(hostname -s)"
BASE="/volume1/Data/pi-backups/${HOST}/${SNAP}"

RSYNC_SSH='ssh -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -o PubkeyAuthentication=yes -o PasswordAuthentication=no -i /root/.ssh/id_ed25519'

if [[ -d "${SRC}" ]]; then
  sudo rsync -aH --numeric-ids --info=stats2 --delete --no-acls --no-xattrs \
    -e "${RSYNC_SSH}" \
    backup@kk-nas-002.local:"${BASE}${SRC%/}/" "${DEST%/}/"
else
  sudo rsync -aH --numeric-ids --info=stats2 --no-acls --no-xattrs \
    -e "${RSYNC_SSH}" \
    backup@kk-nas-002.local:"${BASE}${SRC}" "${DEST}"
fi
echo "Restore complete from ${SNAP}."
