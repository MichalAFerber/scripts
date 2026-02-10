# 🧱 Unbound Architecture & Topology

An overview of your dual-Pi Unbound DNS deployment, including design philosophy, sync flow, and operational layout.

---

## 🧭 System Overview

| Component | Role | IP | Description |
|------------|------|----|-------------|
| **pi4server** | Primary Unbound resolver | 192.168.50.2 | Generates zones, pushes updates |
| **pi4server02** | Secondary Unbound resolver | 192.168.50.3 | Backup resolver and sync target |
| **Router (Asus RT-AX89X)** | DHCP/DNS relay | 192.168.50.1 | Points clients to both Unbound servers |
| **Clients** | Workstations, IoT, NAS | DHCP assigned | Use `mykk.foo` as search domain |

---

## 🗺️ DNS Resolution Flow
```
Client → (DHCP DNS) Router → pi4server (Unbound)
                            ↳ (failover) pi4server02
                            ↳ (recursive) Root hints / upstream
```
Each resolver validates DNSSEC, caches results locally, and serves your internal `mykk.foo` zone.

---

## 🧩 Internal Zone: `mykk.foo`
- Managed via `/etc/unbound/hosts.d/mykk.foo.tsv`
- Auto-converted to `/etc/unbound/unbound.conf.d/mykk.foo.conf` by `update_dns.sh`
- Propagated to `pi4server02` over SSH (`scp`)
- Automatically validated using `unbound-checkconf` prior to reload

---

## 🔄 Sync & Automation

| Script | Purpose |
|--------|----------|
| `update_dns.sh` | Converts `.tsv` to `.conf`, validates, restarts Unbound, and syncs secondary |
| `dns-check.sh` | Performs smoke tests after updates |
| `update-unbound-root-hints.sh` | Refreshes `/var/lib/unbound/root.hints` weekly |
| `install.sh` | Bootstraps Unbound, directories, permissions, and services |
| `sync-to-peer.sh` | Copies zone/conf to peer and reloads Unbound |

### Systemd Timers
- `update-unbound-root-hints.timer` → Refreshes root hints weekly at 03:56  
- Optional: add `sync-dns.timer` if automating zone propagation

---

## 🧩 Security Hardening
- LAN-only access (`access-control: 192.168.50.0/24 allow`)
- Hides identity/version info
- DNSSEC validation enabled
- QNAME minimisation
- Strict caching TTLs (min 1h / max 24h)
- Logs restricted to journal/syslog
- Optionally bind to loopback + LAN interface only

---

## 🧱 File Layout Summary

| Path | Function |
|------|-----------|
| `/etc/unbound/unbound.conf` | Base config (includes `.d/`) |
| `/etc/unbound/unbound.conf.d/lan53.conf` | Server interface + ACL setup |
| `/etc/unbound/unbound.conf.d/mykk.foo.conf` | Generated local zone |
| `/etc/unbound/hosts.d/mykk.foo.tsv` | Source TSV for zone generation |
| `/var/lib/unbound/root.hints` | Root DNS hints file |
| `/usr/local/sbin/update_dns.sh` | Zone update automation |
| `/usr/local/sbin/dns-check.sh` | Health test script |

---

## 🧩 Network Diagram
```
+--------------------------+
| Router (192.168.50.1)    |
| DHCP -> DNS 50.2, 50.3   |
+-----------+--------------+
            |
            v
+-----------+-----------+          +-----------+-----------+
| pi4server (50.2)      |<--sync-->| pi4server02 (50.3)   |
| Primary Unbound        |          | Secondary Unbound    |
| /etc/unbound/...       |          | /etc/unbound/...     |
+-----------+-----------+          +-----------+-----------+
            |
            v
     LAN Clients (mykk.foo)
```

---

## 🕹️ Operations Lifecycle
1. **Edit TSV** → `/etc/unbound/hosts.d/mykk.foo.tsv`  
2. **Run Update Script** → generates `.conf` and reloads service  
3. **Sync** → auto-copies config to `pi4server02`  
4. **Validate** → run `/usr/local/sbin/dns-check.sh`  
5. **Commit Changes** → optional Git push for config versioning  

---

## ⚙️ Maintenance Schedule

| Task | Interval | Script / Command |
|------|-----------|------------------|
| Validate configuration | After each edit | `sudo unbound-checkconf` |
| Update zone | On demand | `sudo /usr/local/sbin/update_dns.sh` |
| Root hints refresh | Weekly | `sudo /usr/local/sbin/update-unbound-root-hints.sh` |
| Restart Unbound | Monthly or post-update | `sudo systemctl restart unbound` |
| Check logs | Weekly | `sudo journalctl -u unbound -p err -n 20` |

---

**Maintainer:** Michal Ferber  
**Environment:** `pi4server`, `pi4server02`  
**Version:** 2025-10-06
