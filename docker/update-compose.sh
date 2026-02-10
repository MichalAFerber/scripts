########################################
# What this script does.
# 
# This script will iterate through all subdirectories in the current directory, 
# check if they contain a docker-compose.yml or compose.yml file, and if so, 
# pull the latest images and restart the containers.
########################################

#!/bin/bash

for d in */; do
  if [ -f "$d/docker-compose.yml" ] || [ -f "$d/compose.yml" ]; then
    echo "▶ Updating $d"
    (cd "$d" && docker compose pull && docker compose up -d)
  fi
done