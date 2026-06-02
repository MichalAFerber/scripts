#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
done

# Filter --dry-run out of positional args
args=()
for arg in "$@"; do
  [[ "$arg" != "--dry-run" ]] && args+=("$arg")
done

FILE="${args[0]:-/etc/unbound/unbound.conf.d/mykk.foo.conf}"
PEER="${args[1]:-pi4server02}"
SSH_OPTS="${SSH_OPTS:-}"

if $DRY_RUN; then
  echo "[dry-run] Would scp $FILE to $PEER:/etc/unbound/unbound.conf.d/"
  echo "[dry-run] Would run unbound-checkconf and reload unbound on $PEER"
  exit 0
fi

echo "Syncing $FILE to $PEER ..."
scp $SSH_OPTS "$FILE" "$PEER:/etc/unbound/unbound.conf.d/"
ssh $SSH_OPTS "$PEER" "sudo unbound-checkconf && sudo systemctl reload unbound || sudo systemctl restart unbound"
echo "Sync complete to $PEER."
