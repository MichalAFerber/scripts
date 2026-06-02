# update_dns
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Reads a TSV file of DNS host records and generates an Unbound local-zone configuration file. Supports A records (with automatic PTR generation) and CNAME records. Backs up the existing config, installs the new one, validates it with unbound-checkconf, and reloads Unbound. Optionally syncs the updated config to a peer DNS server.
### How to Use
```
sudo bash update_dns.sh
```
Preview the generated config without writing anything:
```
bash update_dns.sh --dry-run
```
Prerequisites: `unbound-checkconf`, `awk`, `sed`, and the TSV host file must exist at the expected path.
### What and Where to Tweak
- `ZONE` -- the DNS zone name (default: `mykk.foo`). Change this to match your local domain.
- `TSV` -- path to the tab-separated host file (default: `/etc/unbound/hosts.d/${ZONE}.tsv`).
- `CONF_DIR` / `OUT` -- where the generated Unbound config is written.
- `PEER_HOST` -- hostname of the secondary DNS server to sync to (default: `pi4server02`). Override via environment variable.
- `SYNC_SCRIPT` -- path to the sync helper script (default: `/usr/local/sbin/sync-to-peer.sh`). Override via environment variable.
