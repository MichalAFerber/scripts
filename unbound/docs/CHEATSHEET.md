# 🧰 Unbound DNS Cheatsheet

A quick-reference guide for maintaining and testing Unbound across your dual-Pi home lab setup.

---

## 🔍 Service & Status
```bash
sudo systemctl status unbound
sudo systemctl restart unbound
sudo systemctl reload unbound
```
Follow live logs:
```bash
sudo journalctl -u unbound -f
```

---

## ⚙️ Configuration Validation
```bash
sudo unbound-checkconf
```
Find active includes:
```bash
grep -r "include:" /etc/unbound
```

---

## 🌐 DNS Query Tests
Basic resolution:
```bash
dig @127.0.0.1 example.com +short
```
Compare internal vs external:
```bash
dig @127.0.0.1 google.com
dig @1.1.1.1 google.com
```
Check local zone:
```bash
dig @127.0.0.1 plex.mykk.foo
dig @127.0.0.1 pi4server.mykk.foo
```
DNSSEC validation:
```bash
dig @127.0.0.1 dnssec-failed.org
# Expect SERVFAIL if DNSSEC is enforcing correctly.
```

---

## 🧩 Zone File Management
Edit your internal zone (TSV):
```bash
sudo nano /etc/unbound/hosts.d/mykk.foo.tsv
```
Apply updates:
```bash
sudo /usr/local/sbin/update_dns.sh
```
Verify changes:
```bash
dig @127.0.0.1 <hostname>.mykk.foo
```
Backup before changes:
```bash
sudo cp /etc/unbound/hosts.d/mykk.foo.tsv \  /etc/unbound/hosts.d/mykk.foo.tsv.bak.$(date +%F)
```

---

## 🕹️ Root Hints Maintenance
Manual refresh:
```bash
sudo /usr/local/sbin/update-unbound-root-hints.sh
```
Or trigger systemd timer:
```bash
sudo systemctl start update-unbound-root-hints.service
sudo systemctl status update-unbound-root-hints.timer
```

---

## 🧪 Smoke Tests
Run automated DNS checks:
```bash
/usr/local/sbin/dns-check.sh
```
Manual one-liners:
```bash
dig @192.168.50.2 debian.org +stats
dig @192.168.50.3 debian.org +stats
```

---

## 🔄 Sync Between Pi Servers
Manual sync:
```bash
scp /etc/unbound/unbound.conf.d/mykk.foo.conf pi4server02:/etc/unbound/unbound.conf.d/
ssh pi4server02 "sudo systemctl restart unbound"
```
If automated, confirm sync logs via:
```bash
journalctl -u sync-dns -n 20
```

---

## 🧯 Troubleshooting Quick Reference

| Symptom | Likely Cause | Fix |
|----------|---------------|-----|
| `SERVFAIL` on all domains | Root hints unreachable | Update root hints |
| Local host not resolving | Zone file error or missing reload | Run `update_dns.sh` |
| Config test fails | Bad syntax | `sudo unbound-checkconf` |
| DNS not responding | Port 53 conflict | Check `systemd-resolved` |
| High latency | Slow upstream or caching issue | Restart Unbound, flush cache |

---

## ✅ Health Checklist
- [ ] `systemctl status unbound` → active  
- [ ] `unbound-checkconf` → no errors  
- [ ] Local domains resolve (`plex.mykk.foo`, `pi4server.mykk.foo`)  
- [ ] External domains resolve (`google.com`, `openai.com`)  
- [ ] DNSSEC test returns SERVFAIL for `dnssec-failed.org`  
- [ ] Both Pis respond consistently on port 53  

---

**Maintainer:** Michal Ferber  
**Location:** pi4server / pi4server02  
**Updated:** 2025-10-06
