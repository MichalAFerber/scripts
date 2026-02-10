# 🛡️ Unbound DNS Setup (pi4server + pi4server02)

This README documents the full setup, sync, and maintenance workflow for **Unbound DNS** running on both Raspberry Pi 4 servers in your home lab.

---

## 📋 Overview

- Two redundant Unbound resolvers:
  - `pi4server` → **192.168.50.2**
  - `pi4server02` → **192.168.50.3**
- Each Pi listens on LAN port **53**.
- Asus router points DHCP clients to these DNS servers.
- Config includes:
  - Root hints
  - Local authoritative zone (`mykk.foo`)
  - A/PTR/CNAME records for lab hosts
- Automation:
  - `update_dns.sh` for zone changes
  - rsync/SSH sync between Pis
  - Scheduled root.hints refresh
- Validation scripts to smoke-test DNS health

---

## 🚀 Installation

Run on **each Pi**:
```bash
sudo apt update
sudo apt install -y unbound curl bind9-dnsutils awk coreutils openssh-client
```

Root hints:
```bash
sudo mkdir -p /var/lib/unbound
sudo curl -fsSL -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.root
```

---

## ⚙️ Base Config

`/etc/unbound/unbound.conf`
```conf
include: "/etc/unbound/unbound.conf.d/*.conf"
```

`/etc/unbound/unbound.conf.d/lan53.conf`
```conf
server:
  interface: 192.168.50.2
  interface: 127.0.0.1
  port: 53

  do-ip4: yes
  do-udp: yes
  do-tcp: yes

  access-control: 127.0.0.0/8 allow
  access-control: 192.168.50.0/24 allow

  root-hints: "/var/lib/unbound/root.hints"

  hide-identity: yes
  hide-version: yes
  harden-glue: yes
  harden-dnssec-stripped: yes
  qname-minimisation: yes
  aggressive-nsec: yes
  prefetch: yes
  edns-buffer-size: 1232

  cache-min-ttl: 3600
  cache-max-ttl: 86400

  verbosity: 0
```

Validate & enable:
```bash
sudo unbound-checkconf
sudo systemctl enable --now unbound
```

---

## 🌐 Local Zone: `mykk.foo`

`/etc/unbound/unbound.conf.d/mykk.foo.conf`
```conf
server:
  local-zone: "mykk.foo." static
  # Example records:
  local-data: "pi4server.mykk.foo.   IN A 192.168.50.2"
  local-data: "pi4server02.mykk.foo. IN A 192.168.50.3"
```

Check & restart:
```bash
sudo unbound-checkconf
sudo systemctl restart unbound
```

---

## 🔄 Zone Update Workflow

Add a host (A record):
```bash
printf "newhost\t192.168.50.123\n" | sudo tee -a /etc/unbound/hosts.d/mykk.foo.tsv
sudo /usr/local/sbin/update_dns.sh
```

Add a CNAME:
```bash
printf "media\t@CNAME\ttruenas\n" | sudo tee -a /etc/unbound/hosts.d/mykk.foo.tsv
sudo /usr/local/sbin/update_dns.sh
```

Rollback to backup:
```bash
sudo cp -a /etc/unbound/unbound.conf.d/mykk.foo.conf.bak-YYYY-MM-DD-HHMMSS \          /etc/unbound/unbound.conf.d/mykk.foo.conf
sudo systemctl restart unbound
```

---

## 📡 Router DHCP Setup

On Asus router → **LAN → DHCP Server**:
- **DNS 1:** `192.168.50.2`
- **DNS 2:** `192.168.50.3`
- **Search domain:** `mykk.foo`

Clients now resolve short names across the LAN.

---

## 🛠️ Sync Between Pis

Manual:
```bash
scp /etc/unbound/unbound.conf.d/mykk.foo.conf pi4server02:/etc/unbound/unbound.conf.d/
ssh pi4server02 "sudo systemctl restart unbound"
```

Automated:
- Use `scripts/sync-to-peer.sh` or integrate it into `update_dns.sh` after successful validation.

---

## ⏱️ Root Hints Refresh

Simple cron (weekly):
```bash
echo '56 3 * * 0 root curl -fsSL -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.root && systemctl reload unbound' \ | sudo tee /etc/cron.d/unbound-root-hints
```

Or use the provided systemd service/timer pair:
- `/usr/local/sbin/update-unbound-root-hints.sh`
- `/etc/systemd/system/update-unbound-root-hints.service`
- `/etc/systemd/system/update-unbound-root-hints.timer`

---

## ✅ Validation & Health Checks

### Local dig (on Pi):
```bash
dig @127.0.0.1 example.com +short
dig @192.168.50.2 cloudflare.com +dnssec +multi
```

### Client dig:
```bash
dig @192.168.50.2 openai.com +short
dig @192.168.50.3 openai.com +short
```

### Compare latency:
```bash
for s in 192.168.50.2 192.168.50.3; do
  echo "== $s =="
  dig @$s debian.org +stats | egrep 'Query time|SERVER'
done
```

### Negative test:
```bash
dig @192.168.50.2 nonexistent.example. +norecurse
```

---

## 🔍 Troubleshooting

- **Port 53 conflicts** → Check `systemd-resolved` and disable stub if needed.
- **Firewall** → Allow UDP/TCP 53 only from LAN.
- **Legacy configs** → Remove old Docker Unbound configs (`/opt/unbound/`).
- **SSH noise** → Add `-q` to SSH_OPTS or load keys in `~/.bashrc`.

---

## 📚 Additional Documentation

| Document | Description |
|-----------|--------------|
| [🧰 Cheatsheet](docs/CHEATSHEET.md) | Quick reference for daily operations, validation, and troubleshooting. |
| [🧱 Architecture & Topology](docs/ARCHITECTURE.md) | High-level overview of Unbound design, sync workflow, and network layout. |

> 🧩 Tip: These docs live in `/docs/` and are synced across both Pis.  
> Keep them version-controlled alongside your Unbound scripts and configs.
