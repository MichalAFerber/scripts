#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y unbound curl bind9-dnsutils openssh-client awk coreutils

# Directories
sudo mkdir -p /etc/unbound/unbound.conf.d /etc/unbound/hosts.d /var/lib/unbound

# Copy example configs if not present
[[ -f /etc/unbound/unbound.conf ]] || echo 'include: "/etc/unbound/unbound.conf.d/*.conf"' | sudo tee /etc/unbound/unbound.conf >/dev/null
[[ -f /etc/unbound/unbound.conf.d/lan53.conf ]] || sudo install -Dm0644 etc/unbound/unbound.conf.d/lan53.conf.example /etc/unbound/unbound.conf.d/lan53.conf
[[ -f /etc/unbound/unbound.conf.d/mykk.foo.conf ]] || sudo install -Dm0644 etc/unbound/unbound.conf.d/mykk.foo.conf.example /etc/unbound/unbound.conf.d/mykk.foo.conf
[[ -f /etc/unbound/hosts.d/mykk.foo.tsv ]] || sudo install -Dm0644 etc/unbound/hosts.d/mykk.foo.tsv.sample /etc/unbound/hosts.d/mykk.foo.tsv

# Root hints initial fetch
sudo curl -fsSL -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.root

# Install scripts
sudo install -Dm0755 scripts/update_dns.sh /usr/local/sbin/update_dns.sh
sudo install -Dm0755 scripts/dns-check.sh /usr/local/sbin/dns-check.sh
sudo install -Dm0755 scripts/update-unbound-root-hints.sh /usr/local/sbin/update-unbound-root-hints.sh
sudo install -Dm0755 scripts/sync-to-peer.sh /usr/local/sbin/sync-to-peer.sh

# Systemd timer for root hints
sudo install -Dm0644 systemd/update-unbound-root-hints.service /etc/systemd/system/update-unbound-root-hints.service
sudo install -Dm0644 systemd/update-unbound-root-hints.timer /etc/systemd/system/update-unbound-root-hints.timer
sudo systemctl daemon-reload
sudo systemctl enable --now unbound update-unbound-root-hints.timer

echo "✅ Unbound installed and services enabled."
