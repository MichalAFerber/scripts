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

DEST="/var/lib/unbound/root.hints"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

if $DRY_RUN; then
  echo "[dry-run] Would download https://www.internic.net/domain/named.root"
  echo "[dry-run] Would install to $DEST"
  echo "[dry-run] Would reload unbound"
  exit 0
fi

curl -fsSL -o "$TMP" https://www.internic.net/domain/named.root
sudo install -Dm0644 "$TMP" "$DEST"
sudo systemctl reload unbound || sudo systemctl restart unbound
echo "Root hints updated at $DEST and Unbound reloaded."
