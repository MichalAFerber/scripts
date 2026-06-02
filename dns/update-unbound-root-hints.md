# update-unbound-root-hints
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Downloads the latest DNS root hints file from internic.net and installs it to Unbound's data directory. After updating the file, it reloads (or restarts) Unbound so the new root hints take effect. Typically run on a schedule via a systemd timer.
### How to Use
```
sudo bash update-unbound-root-hints.sh
```
Preview what the script would do without downloading or modifying anything:
```
bash update-unbound-root-hints.sh --dry-run
```
Prerequisites: `curl`, sudo privileges, and Unbound installed with systemd.
### What and Where to Tweak
- `DEST` -- the path where root hints are stored (default: `/var/lib/unbound/root.hints`). Change if your Unbound config points to a different location.
