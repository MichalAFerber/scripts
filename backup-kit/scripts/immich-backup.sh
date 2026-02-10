#!/usr/bin/env bash
# Immich nightly: Postgres dump + uploads sync
set -euo pipefail

##### Variables (edit) #########################################################
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-5432}"
PGDATABASE="${PGDATABASE:-immich}"
PGUSER="${PGUSER:-immich}"
# PGPASSWORD should be set via environment or .pgpass
UPLOADS_DIR="${UPLOADS_DIR:-/srv/immich/uploads}"
LOCAL_DIR="${LOCAL_DIR:-/opt/backups/immich}"
REMOTE_BASE="${REMOTE_BASE:-wasabi-crypt:immich}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
LOG_FILE="${LOG_FILE:-/var/log/immich-backup.log}"
HC_URL="${HC_URL:-}"   # Healthchecks.io ping URL (optional)
###############################################################################

mkdir -p "$LOCAL_DIR/pg" "$(dirname "$LOG_FILE")"

STAMP="$(date +%F)"
DUMP_FILE="$LOCAL_DIR/pg/immich-$STAMP.dump"

{
  echo "=== Immich backup start: $(date) ==="
  # DB dump
  pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -Fc "$PGDATABASE" > "$DUMP_FILE"
  # Rotate local pg dumps
  find "$LOCAL_DIR/pg" -type f -name 'immich-*.dump' -mtime +$RETENTION_DAYS -delete || true

  # Sync uploads and DB offsite
  rclone sync "$UPLOADS_DIR" "$REMOTE_BASE/uploads" --checksum --fast-list --stats 30s
  rclone copy "$LOCAL_DIR/pg" "$REMOTE_BASE/pg" --fast-list --min-age 1d
  echo "=== OK $(date) ==="
} | tee -a "$LOG_FILE"

[ -n "$HC_URL" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL" || true
