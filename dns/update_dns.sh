#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

run() {
  if $DRY_RUN; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

# Config
ZONE="mykk.foo"
TSV="/etc/unbound/hosts.d/${ZONE}.tsv"
CONF_DIR="/etc/unbound/unbound.conf.d"
OUT="${CONF_DIR}/${ZONE}.conf"
BACKUP_TS=$(date +%F-%H%M%S)
PRIMARY_IP=$(hostname -I | awk '{print $1}')
PEER_HOST="${PEER_HOST:-pi4server02}"
SYNC_SCRIPT="${SYNC_SCRIPT:-/usr/local/sbin/sync-to-peer.sh}"

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
require unbound-checkconf
require awk
require sed

[[ -f "$TSV" ]] || { echo "TSV not found: $TSV"; exit 1; }
[[ -d "$CONF_DIR" ]] || run sudo mkdir -p "$CONF_DIR"

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Header
{
  echo "server:"
  echo "  local-zone: \"${ZONE}.\" static"
} > "$TMP"

# Parse TSV
# Lines:
#   host \t 192.168.50.x             -> A record
#   host \t @CNAME \t target-host     -> CNAME
#
# Also generate PTRs for A records.
awk -v zone="$ZONE" '
BEGIN{ FS="\t"; OFS="\t"; }
/^\s*#/ || NF==0 { next }
{
  host=$1; gsub(/^[ \t]+|[ \t]+$/, "", host)
  if ($2=="@CNAME") {
    target=$3; gsub(/^[ \t]+|[ \t]+$/, "", target)
    printf("  local-data: \"%s.%s. IN CNAME %s.%s.\"\n", host, zone, target, zone)
  } else {
    ip=$2; gsub(/^[ \t]+|[ \t]+$/, "", ip)
    printf("  local-data: \"%s.%s. IN A %s\"\n", host, zone, ip)
    printf("  local-data-ptr: \"%s %s.%s.\"\n", ip, host, zone)
  }
}
' "$TSV" >> "$TMP"

if $DRY_RUN; then
  echo "[dry-run] Would generate config:"
  cat "$TMP"
  echo ""
  [[ -f "$OUT" ]] && echo "[dry-run] Would back up $OUT to ${OUT}.bak-${BACKUP_TS}"
  echo "[dry-run] Would install new config to $OUT"
  echo "[dry-run] Would run unbound-checkconf and reload unbound"
  [[ -x "$SYNC_SCRIPT" ]] && echo "[dry-run] Would sync $OUT to ${PEER_HOST} via ${SYNC_SCRIPT}"
  exit 0
fi

# Backup existing conf if present
if [[ -f "$OUT" ]]; then
  sudo cp -a "$OUT" "${OUT}.bak-${BACKUP_TS}"
fi

# Install new conf
sudo install -m0644 "$TMP" "$OUT"

# Validate and reload
sudo unbound-checkconf
sudo systemctl reload unbound || sudo systemctl restart unbound

echo "Updated ${OUT} and reloaded Unbound."

# Optional sync to peer
if [[ -x "$SYNC_SCRIPT" ]]; then
  "$SYNC_SCRIPT" "$OUT" "${PEER_HOST}" && echo "Synced to ${PEER_HOST}."
else
  echo "Sync script not found/executable: ${SYNC_SCRIPT} (skipping)"
fi
