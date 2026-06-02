#!/usr/bin/env bash
# Mirror all repos for a user/org using GitHub CLI
set -euo pipefail

##### Variables (edit) #########################################################
OWNER="${OWNER:-MichalAFerber}"   # user or org
BASE_DIR="${BASE_DIR:-/srv/backup/github/$OWNER}"
REMOTE="${REMOTE:-wasabi-crypt:github/$OWNER}"
LOG_FILE="${LOG_FILE:-/var/log/github-mirror.log}"
HC_URL="${HC_URL:-}"   # Healthchecks.io ping URL (optional)
DRY_RUN=false
###############################################################################

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"
      echo "  --dry-run   Show what would happen without cloning/syncing"
      exit 0
      ;;
  esac
done

RCLONE_DRY=()
if [[ "$DRY_RUN" == "true" ]]; then
  RCLONE_DRY=(--dry-run)
  echo "[DRY RUN] No changes will be made."
fi

mkdir -p "$BASE_DIR" "$(dirname "$LOG_FILE")"

{
  echo "=== GitHub mirror for $OWNER: $(date) ==="
  echo "Dry run: $DRY_RUN"
  cd "$BASE_DIR"
  gh repo list "$OWNER" --limit 1000 --json name,sshUrl,visibility \
    | jq -r '.[].sshUrl' \
    | while read -r url; do
        name=$(basename "$url" .git)
        if [ -d "$name.git" ]; then
          if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY RUN] Would update $name.git"
          else
            git -C "$name.git" remote update --prune
          fi
        else
          if [[ "$DRY_RUN" == "true" ]]; then
            echo "[DRY RUN] Would clone $url → $name.git"
          else
            git clone --mirror "$url" "$name.git"
          fi
        fi
      done
  rclone sync "$BASE_DIR" "$REMOTE" --fast-list --stats 30s "${RCLONE_DRY[@]}"
  echo "=== OK $(date) ==="
} | tee -a "$LOG_FILE"

[ -n "$HC_URL" ] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL" || true
