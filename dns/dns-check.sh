#!/usr/bin/env bash
set -euo pipefail

PRIMARY="${1:-127.0.0.1}"
SECONDARY="${2:-}"

check() {
  local server="$1"
  echo "== Checking server @$server =="
  dig +time=2 +tries=1 @"$server" example.com +short >/dev/null || { echo "FAIL: example.com failed on $server"; return 1; }
  dig +time=2 +tries=1 @"$server" google.com +short >/dev/null || { echo "FAIL: google.com failed on $server"; return 1; }
  dig +time=2 +tries=1 @"$server" plex.mykk.foo +short >/dev/null || echo "WARN: local zone plex.mykk.foo not found on $server"
  if dig +time=2 +tries=1 @"$server" dnssec-failed.org +dnssec | grep -q "status: SERVFAIL"; then
    echo "OK: DNSSEC check (SERVFAIL as expected) on $server"
  else
    echo "WARN: DNSSEC check did not SERVFAIL on $server (validation disabled?)"
  fi
}

check "$PRIMARY" || true
[[ -n "$SECONDARY" ]] && check "$SECONDARY" || true
echo "Done."
