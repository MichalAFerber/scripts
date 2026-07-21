#!/usr/bin/env bash
# Mirror all repos for a user/org using GitHub CLI
set -euo pipefail

##### Variables (edit) #########################################################
OWNER="${OWNER:-MichalAFerber}"   # user or org
BASE_DIR="${BASE_DIR:-/srv/backup/github/$OWNER}"
REMOTE="${REMOTE:-wasabi-crypt:github/$OWNER}"
LOG_FILE="${LOG_FILE:-/var/log/github-mirror.log}"
# Clone transport. https (default) authenticates through git's credential helper
# -- on macOS that is `gh auth git-credential`, which reads the keyring and works
# fine with no TTY. ssh instead needs an ssh-agent holding an unlocked key, which
# launchd and cron do NOT provide, so a passphrase-protected key fails there with
# "Permission denied (publickey)". Use ssh only for unattended keys.
CLONE_PROTO="${CLONE_PROTO:-https}"
HC_URL="${HC_URL:-}"   # Healthchecks.io ping URL (optional)
DRY_RUN=false
###############################################################################

case "$CLONE_PROTO" in
  https) CLONE_FIELD=url ;;
  ssh)   CLONE_FIELD=sshUrl ;;
  *) echo "[ERROR] CLONE_PROTO must be 'https' or 'ssh' (got: $CLONE_PROTO)" >&2; exit 2 ;;
esac

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
  gh repo list "$OWNER" --limit 1000 --json name,url,sshUrl,visibility \
    | jq -r --arg f "$CLONE_FIELD" '.[][$f]' \
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

# Gatus dead-man's-switch push, run in parallel with the Healthchecks.io ping
# above during the migration off Healthchecks. Activate by setting both
# GATUS_PING_URL (this job's external-endpoint URL, e.g.
# https://gatus-c1.thompsonblack.us/api/v1/endpoints/muster_hb-<job>/external)
# and GATUS_PING_TOKEN (its bearer) in the job's environment; unset = no-op.
# Reached only on full success -- set -e aborts earlier on any failure, so a
# failed or skipped run pushes nothing and Gatus alerts on the silence, the
# same contract as the Healthchecks ping.
if [ -n "${GATUS_PING_URL:-}" ] && [ -n "${GATUS_PING_TOKEN:-}" ]; then
  curl -fsS -m 10 --retry 3 -o /dev/null -X POST \
    -H "Authorization: Bearer $GATUS_PING_TOKEN" \
    "$GATUS_PING_URL?success=true" || true
fi
