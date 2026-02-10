#!/usr/bin/env bash
set -euo pipefail
FILE="${1:-/etc/unbound/unbound.conf.d/mykk.foo.conf}"
PEER="${2:-pi4server02}"
SSH_OPTS="${SSH_OPTS:-}"
echo "Syncing $FILE to $PEER ..."
scp $SSH_OPTS "$FILE" "$PEER:/etc/unbound/unbound.conf.d/"
ssh $SSH_OPTS "$PEER" "sudo unbound-checkconf && sudo systemctl reload unbound || sudo systemctl restart unbound"
echo "✅ Sync complete to $PEER."
