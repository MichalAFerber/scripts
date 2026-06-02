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

run sudo apt update
run sudo apt install -y unbound curl bind9-dnsutils openssh-client awk coreutils

# Directories
run sudo mkdir -p /etc/unbound/unbound.conf.d /etc/unbound/hosts.d /var/lib/unbound

# Copy example configs if not present
if [[ ! -f /etc/unbound/unbound.conf ]]; then
  if $DRY_RUN; then
    echo "[dry-run] tee /etc/unbound/unbound.conf (include line)"
  else
    echo 'include: "/etc/unbound/unbound.conf.d/*.conf"' | sudo tee /etc/unbound/unbound.conf >/dev/null
  fi
fi
[[ -f /etc/unbound/unbound.conf.d/lan53.conf ]] || run sudo install -Dm0644 etc/unbound/unbound.conf.d/lan53.conf.example /etc/unbound/unbound.conf.d/lan53.conf
[[ -f /etc/unbound/unbound.conf.d/mykk.foo.conf ]] || run sudo install -Dm0644 etc/unbound/unbound.conf.d/mykk.foo.conf.example /etc/unbound/unbound.conf.d/mykk.foo.conf
[[ -f /etc/unbound/hosts.d/mykk.foo.tsv ]] || run sudo install -Dm0644 etc/unbound/hosts.d/mykk.foo.tsv.sample /etc/unbound/hosts.d/mykk.foo.tsv

# Root hints initial fetch
run sudo curl -fsSL -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.root

# Install scripts
run sudo install -Dm0755 scripts/update_dns.sh /usr/local/sbin/update_dns.sh
run sudo install -Dm0755 scripts/dns-check.sh /usr/local/sbin/dns-check.sh
run sudo install -Dm0755 scripts/update-unbound-root-hints.sh /usr/local/sbin/update-unbound-root-hints.sh
run sudo install -Dm0755 scripts/sync-to-peer.sh /usr/local/sbin/sync-to-peer.sh

# Systemd timer for root hints
run sudo install -Dm0644 systemd/update-unbound-root-hints.service /etc/systemd/system/update-unbound-root-hints.service
run sudo install -Dm0644 systemd/update-unbound-root-hints.timer /etc/systemd/system/update-unbound-root-hints.timer
run sudo systemctl daemon-reload
run sudo systemctl enable --now unbound update-unbound-root-hints.timer

echo "Done. Unbound installed and services enabled."
