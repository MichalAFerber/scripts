#!/usr/bin/env bash
set -euo pipefail

# ===== sysmaint.sh — All-in-one, prompt-driven server upkeep =====
# Safe to re-run any time. Designed for Debian/Ubuntu + Docker hosts.
# Requires: bash 4+, docker (and optionally docker compose plugin), python3 (for email), sudo/root for APT.
#
# Non-interactive quick run (all steps, auto-yes): sudo ./sysmaint.sh --all --yes
#
# Config:
# - Place config.json in the same directory or set SYSMAINT_CONFIG=/path/to/config.json
#
# Logging:
# - Full log:   $SYSMAINT_LOG_DIR/sysmaint-YYYYmmdd-HHMMSS.log
# - Error log:  $SYSMAINT_LOG_DIR/sysmaint-YYYYmmdd-HHMMSS.err.log
#
# Exit codes: 0 success (possibly with non-fatal errors), !0 on unexpected failure.

# ---------- Defaults ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${SYSMAINT_CONFIG:-$SCRIPT_DIR/config.json}"
LOG_DIR="${SYSMAINT_LOG_DIR:-$HOME/.local/share/sysmaint/logs}"
mkdir -p "$LOG_DIR"

TS="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/sysmaint-$TS.log"
ERR_FILE="$LOG_DIR/sysmaint-$TS.err.log"

# Mirror all output to logs
exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$ERR_FILE" >&2)

# Colors (only if TTY)
if [ -t 1 ]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'; GRN=$'\e[32m'; YLW=$'\e[33m'; RED=$'\e[31m'; BLU=$'\e[34m'; RST=$'\e[0m'
else
  BOLD=""; DIM=""; GRN=""; YLW=""; RED=""; BLU=""; RST=""
fi

# ---------- Helpers ----------
have() { command -v "$1" >/dev/null 2>&1; }
is_root() { [ "${EUID:-$(id -u)}" -eq 0 ]; }

# Dry-run mode
DRY_RUN=0

# Wrapper: run a command, or just print it in dry-run mode
run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "${DIM}[dry-run] $*${RST}"
  else
    "$@"
  fi
}

confirm() {
  local prompt="${1:-Proceed?}"
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi
  read -rp "$prompt [y/N]: " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

section() {
  echo -e "\n${BOLD}${BLU}==> $*${RST}\n"
}

warn() { echo -e "${YLW}WARN:${RST} $*" >&2; }
err()  { echo -e "${RED}ERROR:${RST} $*" >&2; }

load_config() {
  if [[ -f "$CONFIG_PATH" ]]; then
    echo "Using config at: $CONFIG_PATH"
  else
    warn "No config.json found at $CONFIG_PATH — email notifications will be skipped unless provided."
  fi
}

send_notification() {
  # Uses notify.py if available + python3; falls back to summary print.
  local status="$1"  # "success" or "error"
  local summary="$2" # short subject/message
  if have python3 && [[ -f "$SCRIPT_DIR/notify.py" && -f "$CONFIG_PATH" ]]; then
    run python3 "$SCRIPT_DIR/notify.py" \
      --config "$CONFIG_PATH" \
      --status "$status" \
      --summary "$summary" \
      --log "$LOG_FILE" \
      --err "$ERR_FILE" || warn "Notification send failed."
  else
    warn "notify.py or config not available; skipping email."
  fi
}

docker_compose_cmd() {
  if have docker && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif have docker-compose; then
    echo "docker-compose"
  else
    echo ""
  fi
}

update_apt() {
  section "APT: update/upgrade/full-upgrade (Debian/Ubuntu)"
  if ! is_root; then
    err "APT operations require root. Re-run with sudo."
    return 1
  fi

  export DEBIAN_FRONTEND=noninteractive
  run apt-get update
  run apt-get -y upgrade
  run apt-get -y full-upgrade
  run apt-get -y autoremove --purge
  run apt-get -y autoclean
}

update_docker_images() {
  section "Docker: update images for compose projects (pull + up -d)"
  if ! have docker; then
    warn "Docker not installed; skipping."
    return 0
  fi

  local DCMD; DCMD="$(docker_compose_cmd)"
  if [[ -n "$DCMD" ]]; then
    # Prefer updating compose projects known to Docker
    if $DCMD ls --format json >/dev/null 2>&1; then
      # New plugin: parse JSON to get project names
      local projects
      projects="$( $DCMD ls --format json | awk -v RS= '{print}' )"
      if [[ -n "$projects" ]]; then
        # shellcheck disable=SC2207
        mapfile -t names < <($DCMD ls --format '{{.Name}}')
        if ((${#names[@]})); then
          for p in "${names[@]}"; do
            echo "→ Updating compose project: $p"
            run $DCMD -p "$p" pull || warn "Pull failed for $p"
            run $DCMD -p "$p" up -d || warn "Up failed for $p"
          done
        else
          warn "No compose projects discovered via '$DCMD ls'."
        fi
      fi
    else
      # Legacy docker-compose without ls JSON
      warn "Compose plugin lacks JSON 'ls'; attempting naive update in CWD (if compose file exists)."
      if [[ -f docker-compose.yml || -f compose.yml || -f docker-compose.yaml || -f compose.yaml ]]; then
        run $DCMD pull || true
        run $DCMD up -d || true
      else
        warn "No compose file in current directory; skipping."
      fi
    fi
  else
    warn "No docker compose command found; skipping compose updates."
  fi

  # Optional: try to refresh standalone containers by image
  section "Docker: attempt to refresh standalone containers"
  # Pull unique images for running containers, then restart containers if image updated
  local images; images="$(docker ps --format '{{.Image}}' | sort -u)"
  if [[ -n "$images" ]]; then
    while IFS= read -r img; do
      echo "Pulling image: $img"
      run docker pull "$img" || warn "Pull failed for $img"
    done <<< "$images"
    # Restart containers to pick up refreshed images (if using image:tag and not digest)
    mapfile -t cnames < <(docker ps --format '{{.Names}}')
    for c in "${cnames[@]}"; do
      echo "Restarting container: $c"
      run docker restart "$c" || warn "Restart failed for $c"
    done
  else
    echo "No running containers found."
  fi
}

prune_docker() {
  section "Docker: pruning unused data"
  if ! have docker; then
    warn "Docker not installed; skipping."
    return 0
  fi
  run docker image prune -af || warn "Image prune failed"
  run docker builder prune -af || warn "Builder prune failed"
  # Keep volumes; uncomment next line if you *really* want to delete unused volumes:
  # run docker volume prune -f || warn "Volume prune failed"
  docker system df || true
}

restart_docker_containers() {
  section "Docker: restarting all running containers"
  if ! have docker; then
    warn "Docker not installed; skipping."
    return 0
  fi
  mapfile -t cnames < <(docker ps --format '{{.Names}}')
  if ((${#cnames[@]})); then
    for c in "${cnames[@]}"; do
      echo "Restarting $c"
      run docker restart "$c" || warn "Restart failed: $c"
    done
  else
    echo "No running containers."
  fi
}

system_report() {
  section "System report (disk, memory, docker df)"
  df -hT || true
  free -h || true
  if have docker; then docker system df || true; fi
}

maybe_reboot() {
  section "Reboot check"
  local need=0
  if [[ -f /var/run/reboot-required ]]; then
    echo "Kernel/packages indicate reboot is required."
    need=1
  fi

  if [[ "$REBOOT_IF_NEEDED" == "1" && $need -eq 1 ]]; then
    echo "Auto-reboot enabled (REBOOT_IF_NEEDED=1). Proceeding."
    run /sbin/reboot || run systemctl reboot || run shutdown -r now || true
  elif [[ $need -eq 1 ]]; then
    if confirm "Reboot now?"; then
      run /sbin/reboot || run systemctl reboot || run shutdown -r now || true
    else
      echo "Reboot deferred."
    fi
  else
    echo "No reboot required."
  fi
}

# ---------- Menu ----------
do_all() {
  update_apt
  update_docker_images
  prune_docker
  restart_docker_containers
  system_report
  maybe_reboot
}

menu() {
  PS3=$'\nSelect an option: '
  local options=(
    "Run ALL (recommended)"
    "APT: update/upgrade/full-upgrade/cleanup"
    "Docker: update images (compose + standalone)"
    "Docker: prune old images/build cache"
    "Docker: restart all running containers"
    "System report (disk/mem/docker space)"
    "Check & (maybe) Reboot"
    "Send test notification"
    "Quit"
  )
  select opt in "${options[@]}"; do
    case "$REPLY" in
      1) do_all ;;
      2) update_apt ;;
      3) update_docker_images ;;
      4) prune_docker ;;
      5) restart_docker_containers ;;
      6) system_report ;;
      7) maybe_reboot ;;
      8) send_notification "success" "Test notification from sysmaint" ;;
      9) break ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

# ---------- CLI ----------
ASSUME_YES=0
REBOOT_IF_NEEDED="${REBOOT_IF_NEEDED:-0}"
RUN_ALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) RUN_ALL=1; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    --reboot-if-needed) REBOOT_IF_NEEDED=1; shift ;;
    --config) CONFIG_PATH="$2"; shift 2 ;;
    --log-dir) LOG_DIR="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      cat <<EOF
Usage: sudo ./sysmaint.sh [OPTIONS]

Options:
  --all                   Run all steps non-interactively
  -y, --yes               Assume yes to prompts
  --reboot-if-needed      Reboot automatically if required
  --config PATH           Path to config.json (for notifications)
  --log-dir DIR           Directory for logs (default: $LOG_DIR)
  --dry-run               Print commands instead of executing them
  -h, --help              Show this help

Examples:
  sudo ./sysmaint.sh                 # interactive menu
  sudo ./sysmaint.sh --all -y        # do everything, no prompts
  sudo ./sysmaint.sh --all -y --reboot-if-needed
  sudo ./sysmaint.sh --all --dry-run # preview what would happen
EOF
      exit 0
      ;;
    *) err "Unknown option: $1"; exit 2 ;;
  esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  section "DRY-RUN MODE — no changes will be made"
fi

section "SysMaint starting @ $(date -Is) on $(hostname)"
echo "Logs: $LOG_FILE"
echo "Errors: $ERR_FILE"
load_config

trap 'RC=$?; echo; echo "SysMaint finished with code $RC @ $(date -Is)"; if [[ $RC -eq 0 && ! -s "$ERR_FILE" ]]; then send_notification "success" "SysMaint OK on $(hostname)"; else send_notification "error" "SysMaint ERRORS on $(hostname)"; fi; exit $RC' EXIT

if [[ $RUN_ALL -eq 1 ]]; then
  do_all
else
  menu
fi
