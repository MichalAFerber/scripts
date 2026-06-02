#!/usr/bin/env bash
set -euo pipefail
SRC_HOST="${1:-kk-nas-002.local}"
DST_HOST="${2:-kk-nas-001.local}"
USER="${3:-backup}"
SRC_BASE="${4:-/volume1/Data/pi-backups}"
DST_BASE="${5:-/volume1/Data/pi-backups}"
SSH_OPT='-o StrictHostKeyChecking=accept-new'
ssh ${SSH_OPT} "${USER}@${DST_HOST}" "mkdir -p '${DST_BASE}'"
ssh -t ${SSH_OPT} "${USER}@${DST_HOST}" "
  rsync -aH --numeric-ids --no-acls --no-xattrs --delete --info=progress2     -e 'ssh ${SSH_OPT}' ${USER}@${SRC_HOST}:'${SRC_BASE}/' '${DST_BASE}/'
"
