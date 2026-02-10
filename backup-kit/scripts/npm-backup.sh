#!/usr/bin/env bash
# Nginx Proxy Manager backup (config volume)
set -euo pipefail

##### Variables (edit) #########################################################
# Option A: back up from a running container by name
NPM_CONTAINER="${NPM_CONTAINER:-nginx-proxy-manager-app-1}"
# Option B: or tar a known host path (leave CONTAINER empty)
NPM_DATA_DIR="${NPM_DATA_DIR:-}"
BACKUP_DIR="${BACKUP_DIR:-/opt/backups/npm}"
LOG_FILE="${LOG_FILE:-/var/log/npm-backup.log}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
HC_URL="${HC_URL:-}"   # Healthchecks.io ping URL (optional)
###############################################################################

mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")"
STAMP="$(date +%F)"
OUT="$BACKUP_DIR/npm-$STAMP.tgz"

{
  echo "=== NPM backup start: $(date) ==="
  if [ -n "$NPM_DATA_DIR" ] && [ -d "$NPM_DATA_DIR" ]; then
    tar -C "$NPM_DATA_DIR" -czf "$OUT" .
  else
    # requires docker on the host; use busybox inside a throwaway container
    docker ps --format '{{.Names}}' | grep -qx "$NPM_CONTAINER"       || { echo "[ERROR] container $NPM_CONTAINER not running and NPM_DATA_DIR unset"; exit 1; }
    docker run --rm --volumes-from "$NPM_CONTAINER" -v "$BACKUP_DIR:/backup" busybox       sh -c 'tar -czf /backup/npm-$(date +%F).tgz -C /data .'
  fi
  find "$BACKUP_DIR" -type f -name 'npm-*.tgz' -mtime +$RETENTION_DAYS -delete || true
  echo "=== OK $(date) ==="
} | tee -a "$LOG_FILE"

[ -n "$HC_URL" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL" || true
