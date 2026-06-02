# update-compose
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Iterates through all subdirectories in the current directory, looks for a docker-compose.yml or compose.yml file, and if found, pulls the latest Docker images and restarts the containers with `docker compose up -d`.
### How to Use
Run from a parent directory that contains your Docker Compose project folders:
```
cd /path/to/docker-projects
./update-compose.sh
```
Preview what would be updated without making changes:
```
./update-compose.sh --dry-run
```
Prerequisites: Docker and the Docker Compose plugin must be installed.
### What and Where to Tweak
- The script looks for `docker-compose.yml` and `compose.yml` by default. If your compose files use a different name, update the `-f` checks in the `if` condition.
- Run the script from whichever parent directory contains your compose project subdirectories.
