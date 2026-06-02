# dns-check
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Performs a quick health check against one or two DNS servers. Tests external resolution (example.com, google.com), local zone resolution (plex.mykk.foo), and DNSSEC validation (expects SERVFAIL for dnssec-failed.org). This is a read-only diagnostic script.
### How to Use
```
bash dns-check.sh [PRIMARY] [SECONDARY]
```
Examples:
```
bash dns-check.sh                          # checks 127.0.0.1 only
bash dns-check.sh 192.168.50.10            # checks a specific server
bash dns-check.sh 192.168.50.10 192.168.50.11  # checks both primary and secondary
```
Prerequisites: `dig` (from bind9-dnsutils or dnsutils package).
### What and Where to Tweak
- The local zone test domain `plex.mykk.foo` is hardcoded. Change it to match a host in your own local zone.
- Default primary server is `127.0.0.1`. Pass a different IP as the first argument if your resolver is elsewhere.
