#!/bin/bash
echo "[$(date '+%F %T')] Starting incremental backup" >> /Users/michal/Library/Logs/com.michal.kopia-backup.stdout
# Password stored in macOS Keychain
/opt/homebrew/bin/kopia repository connect s3 \
  --bucket=ferber-backups \
  --access-key=YourAccessKey \
  --secret-access-key=SuperSecretKey \
  --endpoint=s3.us-east-1.wasabisys.com \
  --region=us-east-1 >> /Users/michal/Library/Logs/com.michal.kopia-backup.stdout 2>> /Users/michal/Library/Logs/com.michal.kopia-backup.stderr
/opt/homebrew/bin/kopia snapshot create /Volumes/Mando >> /Users/michal/Library/Logs/com.michal.kopia-backup.stdout 2>> /Users/michal/Library/Logs/com.michal.kopia-backup.stderr
LATEST_SNAPSHOT=$(/opt/homebrew/bin/kopia snapshot list --json | /opt/homebrew/bin/jq -r '.snapshots[-1].id')
if [[ -n "$LATEST_SNAPSHOT" ]]; then
  echo "[$(date '+%F %T')] Verifying snapshot $LATEST_SNAPSHOT" >> /Users/michal/Library/Logs/com.michal.kopia-backup.stdout
  /opt/homebrew/bin/kopia snapshot verify "$LATEST_SNAPSHOT" >> /Users/michal/Library/Logs/com.michal.kopia-backup.stdout 2>> /Users/michal/Library/Logs/com.michal.kopia-backup.stderr
fi
/opt/homebrew/bin/kopia maintenance run --full >> /Users/michal/Library/Logs/com.michal.kopia-backup.stdout 2>> /Users/michal/Library/Logs/com.michal.kopia-backup.stderr
/opt/homebrew/bin/kopia repository disconnect >> /Users/michal/Library/Logs/com.michal.kopia-backup.stdout 2>> /Users/michal/Library/Logs/com.michal.kopia-backup.stderr
echo "[$(date '+%F %T')] Backup and verification complete" >> /Users/michal/Library/Logs/com.michal.kopia-backup.stdout
