#!/bin/bash

# Load configuration
CONFIG_DIR="$HOME/.config/welcome.sh"
CONFIG_FILE="$CONFIG_DIR/config"
CACHE_DIR="$HOME/.cache/welcome.sh"

# Default configuration
SHOW_FASTFETCH=true
SHOW_WEATHER=true
SHOW_PUBLIC_IP=true
SHOW_SYSTEM_METRICS=true
SHOW_ASCII_ART=false
QUIET_MODE=false
WEATHER_LOCATION=""
CACHE_TIMEOUT=3600
REQUEST_TIMEOUT=3

# Load user config if exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Create cache directory
mkdir -p "$CACHE_DIR"

# Color definitions
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
NC="\033[0m"

# ASCII Art Banner
if [[ "$SHOW_ASCII_ART" == "true" ]]; then
    echo -e "${CYAN}"
    cat << "EOF"
 ██╗    ██╗███████╗██╗      ██████╗ ██████╗ ███╗   ███╗███████╗
 ██║    ██║██╔════╝██║     ██╔════╝██╔═══██╗████╗ ████║██╔════╝
 ██║ █╗ ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║█████╗
 ██║███╗██║██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║██╔══╝
 ╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗
  ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝
EOF
    echo -e "${NC}"
fi

clear

# Helper function to get temperature
get_temp() {
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        temp_millidegree=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo "$((temp_millidegree/1000))°C"
    elif command -v sensors >/dev/null 2>&1; then
        sensors 2>/dev/null | grep -i "Package id 0\|Core 0\|temp1" | head -n 1 | awk '{print $2}' | sed 's/+//'
    else
        echo "N/A"
    fi
}

# Helper function to get cached data
get_cached() {
    local cache_file="$1"
    local max_age="$2"

    if [[ -f "$cache_file" ]]; then
        local file_age=$(($(date +%s) - $(stat -f%m "$cache_file" 2>/dev/null || stat -c%Y "$cache_file" 2>/dev/null)))
        if [[ $file_age -lt $max_age ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    return 1
}

# Helper function to set cached data
set_cached() {
    local cache_file="$1"
    local data="$2"
    echo "$data" > "$cache_file"
}

# Detect OS
OS_TYPE="$(uname -s)"
IS_MACOS=false
[[ "$OS_TYPE" == "Darwin" ]] && IS_MACOS=true

# Helper function for uptime
get_uptime() {
    if [[ "$IS_MACOS" == "true" ]]; then
        uptime | sed 's/.*up \(.*\), [0-9]* users.*/\1/' | sed 's/ *$//' || echo "N/A"
    else
        uptime -p 2>/dev/null || echo "N/A"
    fi
}

# Helper function for load average
get_load_average() {
    if [[ "$IS_MACOS" == "true" ]]; then
        uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//' || echo "N/A"
    else
        cut -d ' ' -f1-3 /proc/loadavg 2>/dev/null || echo "N/A"
    fi
}

# Helper function for top CPU process
get_top_cpu() {
    if [[ "$IS_MACOS" == "true" ]]; then
        ps -A -o %cpu=,comm= 2>/dev/null | sort -rn | head -n1 | awk '{printf "%s (%.1f%%)", $2, $1}' || echo ""
    else
        ps aux --sort=-%cpu 2>/dev/null | awk 'NR==2 {printf "%s (%.1f%%)", $11, $3}' || echo ""
    fi
}

# Run fastfetch if enabled
if [[ "$SHOW_FASTFETCH" == "true" ]]; then
    command -v fastfetch >/dev/null && fastfetch -c all
fi

CYAN="\033[1;36m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"
NC="\033[0m"

echo -e "${CYAN}Hello, $USER!${NC}"
echo -e "${YELLOW}Uptime: $(get_uptime) | Load Average: $(get_load_average)${NC}"

# Public IP with caching
if [[ "$SHOW_PUBLIC_IP" == "true" ]]; then
    PUBIP_CACHE="$CACHE_DIR/public_ip"
    PUBIP=$(get_cached "$PUBIP_CACHE" "$CACHE_TIMEOUT")
    if [[ $? -ne 0 ]]; then
        PUBIP=$(timeout "$REQUEST_TIMEOUT" curl -s ifconfig.me 2>/dev/null || echo "N/A")
        [[ "$PUBIP" != "N/A" ]] && set_cached "$PUBIP_CACHE" "$PUBIP"
    fi
    echo -e "${GREEN}Public IP: $PUBIP${NC}"
fi

echo -e "${CYAN}Disk Usage on /:$(df -h / | awk 'NR==2 {print " " $3 " used of " $2 " (" $5 ")"}')${NC}"

# System Metrics Dashboard
if [[ "$SHOW_SYSTEM_METRICS" == "true" ]]; then
    # Memory usage
    if command -v free >/dev/null 2>&1; then
        MEM_INFO=$(free -h | awk 'NR==2 {printf "Used: %s / %s (%.0f%%)", $3, $2, ($3/$2)*100}')
        echo -e "${BLUE}Memory: $MEM_INFO${NC}"
    elif [[ "$IS_MACOS" == "true" ]]; then
        # macOS memory usage
        MEM_INFO=$(vm_stat 2>/dev/null | awk '/^Pages free:/ {free=$3} /^Pages active:/ {active=$3} /^Pages inactive:/ {inactive=$3} END {total=8*1024; used=active+inactive; printf "Used: %.2f GiB / 8.00 GiB (%.0f%%)", used/1024/1024, (used/(used+free))*100}')
        echo -e "${BLUE}Memory: $MEM_INFO${NC}"
    fi

    # Top processes by CPU
    if [[ "$QUIET_MODE" != "true" ]]; then
        TOP_CPU=$(get_top_cpu)
        [[ -n "$TOP_CPU" ]] && echo -e "${MAGENTA}Top CPU: $TOP_CPU${NC}"
    fi
fi

# Multi-distro package manager support
if command -v apt >/dev/null 2>&1; then
    UPDATES=$(apt list --upgradeable 2>/dev/null | grep -v "Listing..." | wc -l)
    if [ "$UPDATES" -gt 0 ]; then
        echo -e "${RED}Updates available: $UPDATES package(s)${NC}"
    else
        echo -e "${GREEN}Your system is up to date.${NC}"
    fi
elif command -v dnf >/dev/null 2>&1; then
    UPDATES=$(dnf check-update -q 2>/dev/null | grep -v "^$" | wc -l)
    [[ "$UPDATES" -gt 0 ]] && echo -e "${RED}Updates available: $UPDATES package(s)${NC}" || echo -e "${GREEN}Your system is up to date.${NC}"
elif command -v yum >/dev/null 2>&1; then
    UPDATES=$(yum check-update -q 2>/dev/null | grep -v "^$" | wc -l)
    [[ "$UPDATES" -gt 0 ]] && echo -e "${RED}Updates available: $UPDATES package(s)${NC}" || echo -e "${GREEN}Your system is up to date.${NC}"
elif command -v pacman >/dev/null 2>&1; then
    UPDATES=$(pacman -Qu 2>/dev/null | wc -l)
    [[ "$UPDATES" -gt 0 ]] && echo -e "${RED}Updates available: $UPDATES package(s)${NC}" || echo -e "${GREEN}Your system is up to date.${NC}"
elif command -v zypper >/dev/null 2>&1; then
    UPDATES=$(zypper list-updates 2>/dev/null | grep -c "|")
    [[ "$UPDATES" -gt 0 ]] && echo -e "${RED}Updates available: $UPDATES package(s)${NC}" || echo -e "${GREEN}Your system is up to date.${NC}"
fi

if [ -f /var/run/reboot-required ]; then
    echo -e "${RED}⚠️  Reboot required!${NC}"
fi

# --- CPU Temperature and Throttling ---
TEMP=$(get_temp)
echo -e "${CYAN}CPU Temp: $TEMP${NC}"

# Improved Raspberry Pi detection
IS_RPI=false
if [[ -f /proc/device-tree/model ]] && grep -qi "raspberry pi" /proc/device-tree/model 2>/dev/null; then
    IS_RPI=true
elif [[ -f /boot/config.txt ]] || [[ -f /boot/firmware/config.txt ]]; then
    IS_RPI=true
fi

# Throttling: only on Raspberry Pi
if [[ "$IS_RPI" == "true" ]] && command -v vcgencmd >/dev/null 2>&1; then
    RAW_OUTPUT=$(vcgencmd get_throttled 2>/dev/null || true)
    if [[ "$RAW_OUTPUT" == throttled=* ]]; then
        THROTTLED_RAW=$(echo "$RAW_OUTPUT" | cut -d= -f2)
        if [ "$THROTTLED_RAW" != "0x0" ]; then
            THROTTLE_STATUS="${RED}Yes ($THROTTLED_RAW)${NC}"
        else
            THROTTLE_STATUS="${GREEN}No${NC}"
        fi
        echo -e "${CYAN}Throttled: $THROTTLE_STATUS${NC}"
    fi
fi

# --- Weather with caching ---
if [[ "$SHOW_WEATHER" == "true" ]]; then
    WEATHER_CACHE="$CACHE_DIR/weather"
    WEATHER=$(get_cached "$WEATHER_CACHE" "$CACHE_TIMEOUT")
    if [[ $? -ne 0 ]]; then
        LOCATION="${WEATHER_LOCATION:-}"
        [[ -z "$LOCATION" ]] && LOCATION="Lake+City"
        WEATHER=$(timeout "$REQUEST_TIMEOUT" curl -s "wttr.in/${LOCATION}?format=3" 2>/dev/null || echo "N/A")
        [[ "$WEATHER" != "N/A" ]] && set_cached "$WEATHER_CACHE" "$WEATHER"
    fi
    echo -e "${YELLOW}Weather: $WEATHER${NC}"
fi

echo -e "${YELLOW}You are good to go for Whiskey, Tango, Foxtrot!${NC}"
