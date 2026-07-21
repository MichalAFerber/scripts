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
DRY_RUN=false
###############################################################################

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"
      echo "  --dry-run   Show what would happen without creating/deleting backups"
      exit 0
      ;;
  esac
done

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY RUN] No changes will be made."
fi

mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")"
STAMP="$(date +%F)"
OUT="$BACKUP_DIR/npm-$STAMP.tgz"

{
  echo "=== NPM backup start: $(date) ==="
  echo "Dry run: $DRY_RUN"

  if [ -n "$NPM_DATA_DIR" ] && [ -d "$NPM_DATA_DIR" ]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY RUN] Would create tarball from $NPM_DATA_DIR → $OUT"
    else
      tar -C "$NPM_DATA_DIR" -czf "$OUT" .
    fi
  else
    # requires docker on the host; use busybox inside a throwaway container
    docker ps --format '{{.Names}}' | grep -qx "$NPM_CONTAINER" \
      || { echo "[ERROR] container $NPM_CONTAINER not running and NPM_DATA_DIR unset"; exit 1; }
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY RUN] Would create tarball from container $NPM_CONTAINER volumes → $OUT"
    else
      docker run --rm --volumes-from "$NPM_CONTAINER" -v "$BACKUP_DIR:/backup" busybox \
        sh -c 'tar -czf /backup/npm-$(date +%F).tgz -C /data .'
    fi
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] Would delete backups older than $RETENTION_DAYS days:"
    find "$BACKUP_DIR" -type f -name 'npm-*.tgz' -mtime +$RETENTION_DAYS 2>/dev/null || true
  else
    find "$BACKUP_DIR" -type f -name 'npm-*.tgz' -mtime +$RETENTION_DAYS -delete || true
  fi
  echo "=== OK $(date) ==="
} | tee -a "$LOG_FILE"

[ -n "$HC_URL" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL" || true

# Gatus dead-man's-switch push, run in parallel with the Healthchecks.io ping
# above during the migration off Healthchecks. Activate by setting both
# GATUS_PING_URL (this job's external-endpoint URL, e.g.
# https://gatus-c1.thompsonblack.us/api/v1/endpoints/muster_hb-<job>/external)
# and GATUS_PING_TOKEN (its bearer) in the job's environment; unset = no-op.
# Reached only on full success -- set -e aborts earlier on any failure, so a
# failed or skipped run pushes nothing and Gatus alerts on the silence, the
# same contract as the Healthchecks ping.
if [ -n "${GATUS_PING_URL:-}" ] && [ -n "${GATUS_PING_TOKEN:-}" ]; then
  curl -fsS -m 10 --retry 3 -o /dev/null -X POST \
    -H "Authorization: Bearer $GATUS_PING_TOKEN" \
    "$GATUS_PING_URL?success=true" || true
fi
