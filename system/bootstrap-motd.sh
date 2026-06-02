#!/usr/bin/env bash
# Normalize MOTD on Ubuntu hosts — quiet, but keep useful info.
# Idempotent; safe to re-run.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    exec sudo -E "$0" "$@"
fi

echo "[motd] Installing required packages..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    update-notifier-common \
    ubuntu-pro-client \
    ubuntu-advantage-tools

echo "[motd] Silencing noisy motd scripts..."
SILENCE=(
    10-help-text
    50-motd-news
    50-landscape-sysinfo
    85-fwupd
    91-contract-ua-esm-status
    91-release-upgrade
    95-hwe-eol
    97-overlayroot
    98-fsck-at-reboot
    98-reboot-required
)
for f in "${SILENCE[@]}"; do
    path="/etc/update-motd.d/$f"
    [[ -e "$path" ]] && chmod -x "$path" || true
done

echo "[motd] Disabling motd-news fetcher..."
if [[ -f /etc/default/motd-news ]]; then
    sed -i 's/^ENABLED=1/ENABLED=0/' /etc/default/motd-news
fi
systemctl disable --now motd-news.timer motd-news.service 2>/dev/null || true

echo "[motd] Regenerating updates-available cache..."
/usr/lib/update-notifier/update-motd-updates-available 2>/dev/null || \
    /usr/lib/update-notifier/apt-check --human-readable > /var/lib/update-notifier/updates-available

echo "[motd] Removing landscape-common if installed (Canonical ads)..."
apt-get purge -y landscape-common 2>/dev/null || true
apt-get autoremove -y

echo "[motd] Done."
