#!/usr/bin/env bash
# Keep only last N snapshots for this host (default 14).
set -euo pipefail
HOST="$(hostname -s)"
KEEP="${1:-14}"
ssh -o StrictHostKeyChecking=accept-new backup@kk-nas-002.local \
  "cd /volume1/Data/pi-backups/${HOST} && ls -1dt 20* | tail -n +$((KEEP+1)) | xargs -r rm -rf --"
echo "Pruned to keep last ${KEEP} snapshots for ${HOST}."
