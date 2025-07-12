#!/bin/bash

# =============================================================================
# Script: start-docker-services.sh
# Author: Michal A. Ferber
# Repository: https://github.com/MichalAFerber/scripts/docker
# License: MIT
#
# Description:
#   Starts and monitors Docker services—both Compose-based and standalone—
#   ensuring containers are healthy, restarting if needed, and reporting status.
#
# Usage:
#   ./start-docker-services.sh
#
# Customize:
#   1. Add your Compose or standalone container services below.
#   2. Adjust container names, paths, and domains as needed.
#
# Log:
#   Output is written to ~/start-docker-services.log
# =============================================================================

# Redirect all output to log file
exec >> "$HOME/start-docker-services.log" 2>&1
echo "==== Starting Docker Services at $(date) ===="

# Function: Check if a container is running and healthy
check_container() {
    local container_name=$1
    local status=$(docker inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found")
    local health=$(docker inspect --format '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no_health")

    if [[ "$status" == "running" ]]; then
        if [[ "$health" == "healthy" || "$health" == "no_health" ]]; then
            echo "✅ $container_name is running and healthy"
            return 0
        else
            echo "⚠️ $container_name is running but unhealthy"
            return 1
        fi
    else
        echo "❌ $container_name is not running (status: $status)"
        return 1
    fi
}

# Function: Start or restart a Docker Compose service
start_compose_service() {
    local dir=$1
    local name=$2
    echo "🔍 Checking $name in $dir"

    if [[ ! -f "$dir/docker-compose.yml" ]]; then
        echo "⚠️ No docker-compose.yml found in $dir, skipping..."
        return 1
    fi

    local running=$(docker compose -f "$dir/docker-compose.yml" ps -q | wc -l)

    if [[ "$running" -gt 0 ]]; then
        local all_healthy=true
        for cid in $(docker compose -f "$dir/docker-compose.yml" ps -q); do
            cname=$(docker inspect --format '{{.Name}}' "$cid" | sed 's/^\/\+//')
            if ! check_container "$cname"; then
                all_healthy=false
                break
            fi
        done

        if $all_healthy; then
            echo "✅ $name is already running and healthy"
        else
            echo "🔁 Restarting $name due to unhealthy containers..."
            cd "$dir" && docker compose down && docker compose up -d
        fi
    else
        echo "▶️ Starting $name..."
        cd "$dir" && docker compose up -d
    fi
}

# Function: Start a standalone container
start_container() {
    local name=$1
    echo "🔍 Checking standalone container: $name"
    if check_container "$name"; then
        echo "✅ $name is already running and healthy"
    else
        echo "▶️ Starting $name..."
        docker start "$name" || {
            echo "⚠️ Failed to start $name, attempting to recreate..."
            docker rm -f "$name"
            docker run -d --name "$name" --restart unless-stopped \
                -p 9000:9000 -p 9443:9443 \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v portainer_data:/data \
                portainer/portainer-ce:lts
        }
    fi
}

# Function: Wait for Docker daemon
wait_for_docker() {
    echo "⏳ Waiting for Docker daemon..."
    for i in {1..30}; do
        if docker info >/dev/null 2>&1; then
            echo "✅ Docker daemon is ready"
            return
        fi
        echo "🕒 Docker not ready, retrying... ($i/30)"
        sleep 2
    done
    echo "❌ Docker daemon did not become ready in time"
    exit 1
}

# Function: Connect service container to extra networks
connect_networks() {
    local container=$1
    shift
    local networks=("$@")
    for net in "${networks[@]}"; do
        docker network connect "$net" "$container" 2>/dev/null \
            && echo "🔗 Connected $container to $net" \
            || echo "⚠️ Failed to connect $container to $net (maybe already connected)"
    done
}

# Function: Check service URL availability
check_urls() {
    for url in "$@"; do
        if curl -k -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|301\|302"; then
            echo "🌐 $url is accessible"
        else
            echo "❌ $url is NOT accessible"
        fi
    done
}

# === MAIN SCRIPT LOGIC ===

wait_for_docker

# === Modify these services as needed ===
start_container "portainer"
start_compose_service "$HOME/corecontrol" "CoreControl"
start_compose_service "$HOME/speedtest-tracker" "Speedtest-Tracker"
start_compose_service "$HOME/portnote" "PortNote"
start_compose_service "$HOME/actual-budget" "ActualBudget"

echo "⏱️ Waiting 30 seconds for services to stabilize..."
sleep 30

start_compose_service "$HOME/nginx-proxy-manager" "Nginx-Proxy-Manager"

connect_networks "nginx-proxy-manager-app-1" \
    corecontrol_default speedtest-tracker_default actual_server npm-network bridge

check_urls \
    https://hostname/app_path1:port/ \
    https://hostname/app_path2:port/ \
    https://hostname/app_path3:port/ \
    https://hostname/app_path4:port/

echo "✅ All services checked. Script finished at $(date)"
