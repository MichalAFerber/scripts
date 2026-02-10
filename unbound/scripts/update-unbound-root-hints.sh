#!/usr/bin/env bash
set -euo pipefail
DEST="/var/lib/unbound/root.hints"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

curl -fsSL -o "$TMP" https://www.internic.net/domain/named.root
sudo install -Dm0644 "$TMP" "$DEST"
sudo systemctl reload unbound || sudo systemctl restart unbound
echo "✅ Root hints updated at $DEST and Unbound reloaded."
