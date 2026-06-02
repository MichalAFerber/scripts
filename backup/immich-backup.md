# immich-backup
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Performs a nightly backup of an Immich photo server. Dumps the PostgreSQL database to a local file, rotates old dumps beyond a retention window, then syncs both the uploads directory and database dumps to a Wasabi S3 bucket via rclone. Optionally pings Healthchecks.io on completion.
### How to Use
```bash
# Run the backup
./immich-backup.sh

# Preview what would happen without making changes
./immich-backup.sh --dry-run
```
**Prerequisites:**
- `pg_dump` available (PostgreSQL client tools)
- `rclone` installed and configured with a `wasabi-crypt` remote
- `PGPASSWORD` set via environment variable or `~/.pgpass`
- Immich uploads directory accessible at the configured path
### What and Where to Tweak
- `PGHOST` / `PGPORT` / `PGDATABASE` / `PGUSER` -- PostgreSQL connection details (defaults: `127.0.0.1:5432`, database `immich`, user `immich`)
- `UPLOADS_DIR` -- Path to Immich uploads (default: `/srv/immich/uploads`)
- `LOCAL_DIR` -- Local backup staging directory (default: `/opt/backups/immich`)
- `REMOTE_BASE` -- rclone remote destination (default: `wasabi-crypt:immich`)
- `RETENTION_DAYS` -- How many days to keep local DB dumps (default: `14`)
- `LOG_FILE` -- Log file path (default: `/var/log/immich-backup.log`)
- `HC_URL` -- Healthchecks.io ping URL for monitoring (optional)
