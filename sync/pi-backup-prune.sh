#!/usr/bin/env bash
# Keep only last N snapshots for this host (default 14).
set -euo pipefail

DRY_RUN=false
KEEP=14

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    [0-9]*) KEEP="$arg" ;;
  esac
done

HOST="$(hostname -s)"
TO_DELETE="$(ssh -o StrictHostKeyChecking=accept-new backup@kk-nas-002.local \
  "cd /volume1/Data/pi-backups/${HOST} && ls -1dt 20* | tail -n +$((KEEP+1))" 2>/dev/null || true)"

if [[ -z "${TO_DELETE}" ]]; then
  echo "Nothing to prune (${KEEP} or fewer snapshots exist for ${HOST})."
  exit 0
fi

echo "Snapshots to remove for ${HOST}:"
echo "${TO_DELETE}"

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "(dry run -- no snapshots were deleted)"
else
  ssh -o StrictHostKeyChecking=accept-new backup@kk-nas-002.local \
    "cd /volume1/Data/pi-backups/${HOST} && echo '${TO_DELETE}' | xargs -r rm -rf --"
  echo "Pruned to keep last ${KEEP} snapshots for ${HOST}."
fi
