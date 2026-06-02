# bootstrap-motd
## Michal Ferber
## Revised Date: 05/26/2026
### Description
Normalizes the MOTD (Message of the Day) on Ubuntu hosts — quiet but informative. Removes Canonical's marketing noise (landscape-common, motd-news), silences chatty MOTD scripts (help text, hwe-eol, release-upgrade nags, etc.), and regenerates the updates-available cache so SSH login still tells you what packages need attention. Idempotent — safe to re-run.

### How to Use

```bash
# Auto-elevates with sudo if not run as root
./bootstrap-motd.sh

# Or run directly as root
sudo ./bootstrap-motd.sh
```

### What it does (in order)

1. Installs `update-notifier-common`, `ubuntu-pro-client`, `ubuntu-advantage-tools`.
2. Silences noisy MOTD scripts in `/etc/update-motd.d/` by removing their execute bit:
   - `10-help-text`
   - `50-motd-news`, `50-landscape-sysinfo`
   - `85-fwupd`
   - `91-contract-ua-esm-status`, `91-release-upgrade`
   - `95-hwe-eol`
   - `97-overlayroot`
   - `98-fsck-at-reboot`, `98-reboot-required`
3. Disables `motd-news.timer` / `.service` (fetches Canonical marketing news).
4. Regenerates the updates-available cache.
5. Purges `landscape-common` (Canonical ads on login).

### Requirements

- Ubuntu (uses `apt-get`, `update-motd.d`, `systemctl`)
- Root / sudo
- Internet access for package install

### Notes

- This **silences** existing MOTD scripts (chmod -x) rather than deleting them, so package updates that touch those files won't override your customizations.
- Pairs well with [`welcome.sh`](welcome.md) for a custom login experience after the noise is gone.
