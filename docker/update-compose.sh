########################################
# What this script does.
#
# This script will iterate through all subdirectories in the current directory,
# check if they contain a docker-compose.yml or compose.yml file, and if so,
# pull the latest images and restart the containers.
#
# Options:
#   --dry-run   Show what would be updated without pulling or restarting.
########################################

#!/bin/bash

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

for d in */; do
  if [ -f "$d/docker-compose.yml" ] || [ -f "$d/compose.yml" ]; then
    if $DRY_RUN; then
      echo "[DRY RUN] Would update $d"
    else
      echo "▶ Updating $d"
      (cd "$d" && docker compose pull && docker compose up -d)
    fi
  fi
done
