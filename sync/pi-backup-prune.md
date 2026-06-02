# pi-backup-prune
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Deletes old Pi backup snapshots on a Synology NAS, keeping only the most recent N snapshots (default 14). Connects to the NAS over SSH, lists timestamped snapshot directories, and removes the oldest ones beyond the retention count.
### How to Use
```bash
# Preview which snapshots would be deleted (no changes made)
./pi-backup-prune.sh --dry-run

# Delete old snapshots, keeping the last 14 (default)
./pi-backup-prune.sh

# Keep only the last 7 snapshots
./pi-backup-prune.sh 7

# Preview pruning to 7 snapshots
./pi-backup-prune.sh 7 --dry-run
```
Prerequisites: SSH key-based auth configured for `backup@kk-nas-002.local`.
### What and Where to Tweak
- `KEEP` (line 6): Default number of snapshots to retain (can also be passed as a positional argument).
- NAS connection string `backup@kk-nas-002.local` (lines 17, 33): Change to match your NAS hostname and user.
- NAS backup path `/volume1/Data/pi-backups` (lines 17, 33): Adjust if backups are stored elsewhere.
