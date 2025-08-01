#!/usr/bin/env bash
#
# Ubuntu Post-Install Setup Script
#
# Usage:
#   Interactive (with reboot prompt):
#     ./post_install_setup.sh
#
#   Remote (non-interactive, no reboot prompt):
#     bash <(curl -fsSL https://raw.githubusercontent.com/MichalAFerber/scripts/main/ubuntu/post_install_setup.sh)
#
# What this script does:
#   - Sets timezone to America/New_York
#   - Enables NTP
#   - Updates and upgrades packages
#   - Installs and enables avahi-daemon
#   - Adds Fastfetch PPA and installs fastfetch
#
# Notes:
#   - Intended for Ubuntu only (not Kali or other distros)
#   - Safe to re-run; checks for existing packages and PPA
#
# Date: 2025-08-01
#

set -euo pipefail

# --- CONFIGURATION ---
TIMEZONE="America/New_York"
FASTFETCH_PPA="ppa:zhangsongcui3371/fastfetch"

log() {
    echo -e "\n\033[1;32m[INFO]\033[0m $1\n"
}

# --- 1. Timezone & NTP ---
log "Setting timezone to $TIMEZONE"
sudo timedatectl set-timezone "$TIMEZONE"

log "Enabling NTP synchronization"
sudo timedatectl set-ntp true

# --- 2. Update & Upgrade ---
log "Updating package lists and upgrading system"
sudo apt update -y
sudo apt full-upgrade -y

# --- 3. Install avahi-daemon ---
log "Installing and enabling avahi-daemon"
if ! dpkg -l | grep -q avahi-daemon; then
    sudo apt install -y avahi-daemon
else
    log "avahi-daemon already installed"
fi

sudo systemctl enable --now avahi-daemon

# --- 4. Add Fastfetch PPA and Install ---
log "Installing dependencies for add-apt-repository"
sudo apt install -y software-properties-common

# Add PPA if not already present
if ! grep -Rq "^deb .*$FASTFETCH_PPA" /etc/apt/sources.list.d/; then
    log "Adding Fastfetch PPA"
    sudo add-apt-repository -y "$FASTFETCH_PPA"
else
    log "Fastfetch PPA already exists"
fi

log "Updating package lists"
sudo apt update -y

log "Installing fastfetch"
sudo apt install -y fastfetch

log "Post-install setup completed successfully!"

# --- Reboot Prompt ---
if [ -t 0 ]; then
    # Interactive shell
    read -rp "Do you want to reboot now? (y/N): " REBOOT_CHOICE
    if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
        log "Rebooting..."
        sudo reboot
    else
        log "Reboot skipped. Please reboot manually later."
    fi
else
    # Non-interactive (likely run via curl)
    log "Non-interactive run detected. Skipping reboot prompt."
fi
