# sync-to-peer
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Copies an Unbound configuration file to a peer DNS server via scp, then validates and reloads Unbound on the remote host via ssh. Used to keep a secondary DNS server in sync after local config changes.
### How to Use
```
bash sync-to-peer.sh [FILE] [PEER_HOST]
```
Examples:
```
bash sync-to-peer.sh /etc/unbound/unbound.conf.d/mykk.foo.conf pi4server02
bash sync-to-peer.sh --dry-run
```
The `--dry-run` flag can appear anywhere in the arguments. It shows what would happen without transferring files or running remote commands.

Prerequisites: SSH key-based access to the peer host, `scp`, `ssh`.
### What and Where to Tweak
- First positional argument -- the config file to sync (default: `/etc/unbound/unbound.conf.d/mykk.foo.conf`).
- Second positional argument -- the peer hostname (default: `pi4server02`).
- `SSH_OPTS` -- environment variable for extra ssh/scp options (e.g., `-i /path/to/key` or `-o StrictHostKeyChecking=no`).
