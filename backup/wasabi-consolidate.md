# wasabi-consolidate
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Reorganizes S3 prefixes (virtual folders) within a Wasabi bucket by moving contents from legacy/scattered prefixes into a clean `backups/` hierarchy, then purges the empty source prefixes. Runs in dry-run mode by default for safety. Skips files that already exist at the destination.
### How to Use
```bash
# Preview what would happen (dry-run is the default)
./wasabi-consolidate.sh

# Actually apply the moves and purges
DRY_RUN=false ./wasabi-consolidate.sh
```
**Prerequisites:**
- `rclone` installed and configured with a `wasabi-ferber` remote
- Wasabi S3 credentials configured in rclone
### What and Where to Tweak
- `REMOTE` -- rclone remote and bucket (default: `wasabi-ferber:ferber-storage`)
- `RCLONE_FLAGS` -- Tuning flags for transfers/checkers (default: 16 each, fast-list, ignore-existing)
- `DRY_RUN` -- Set to `false` to apply changes (default: `true`)
- The `move_merge` calls at the bottom define which prefixes get moved where -- edit these to match your actual reorganization needs
