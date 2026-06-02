# npm-backup
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Backs up the Nginx Proxy Manager (NPM) configuration data volume to a compressed tarball. Can pull data either from a running Docker container's volumes or from a known host path. Old backups beyond the retention period are automatically cleaned up. Optionally pings Healthchecks.io on completion.
### How to Use
```bash
# Back up from the running container
./npm-backup.sh

# Back up from a host directory instead
NPM_DATA_DIR=/path/to/npm/data ./npm-backup.sh

# Preview what would happen
./npm-backup.sh --dry-run
```
**Prerequisites:**
- `docker` installed and running (if backing up from a container)
- The NPM container must be running (default name: `nginx-proxy-manager-app-1`)
- Write access to the backup directory and log file location
### What and Where to Tweak
- `NPM_CONTAINER` -- Docker container name to pull volumes from (default: `nginx-proxy-manager-app-1`)
- `NPM_DATA_DIR` -- Host path to NPM data directory; if set, tar is used directly instead of Docker (default: empty)
- `BACKUP_DIR` -- Where tarballs are stored (default: `/opt/backups/npm`)
- `LOG_FILE` -- Log file path (default: `/var/log/npm-backup.log`)
- `RETENTION_DAYS` -- How many days to keep old backups (default: `14`)
- `HC_URL` -- Healthchecks.io ping URL for monitoring (optional)
