#!/usr/bin/env bash
# Mirror all repos for a user/org using GitHub CLI
set -euo pipefail

##### Variables (edit) #########################################################
OWNER="${OWNER:-MichalAFerber}"   # user or org
BASE_DIR="${BASE_DIR:-/srv/backup/github/$OWNER}"
REMOTE="${REMOTE:-wasabi-crypt:github/$OWNER}"
LOG_FILE="${LOG_FILE:-/var/log/github-mirror.log}"
HC_URL="${HC_URL:-}"   # Healthchecks.io ping URL (optional)
###############################################################################

mkdir -p "$BASE_DIR" "$(dirname "$LOG_FILE")"

{
  echo "=== GitHub mirror for $OWNER: $(date) ==="
  cd "$BASE_DIR"
  gh repo list "$OWNER" --limit 1000 --json name,sshUrl,visibility     | jq -r '.[].sshUrl'     | while read -r url; do
        name=$(basename "$url" .git)
        if [ -d "$name.git" ]; then
          git -C "$name.git" remote update --prune
        else
          git clone --mirror "$url" "$name.git"
        fi
      done
  rclone sync "$BASE_DIR" "$REMOTE" --fast-list --stats 30s
  echo "=== OK $(date) ==="
} | tee -a "$LOG_FILE"

[ -n "$HC_URL" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL" || true
