# welcome
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Login welcome/MOTD script that displays a colorful system status dashboard when you open a terminal. Shows a greeting, system uptime, load average, public IP (cached), disk usage, memory usage, top CPU process, available package updates, CPU temperature, Raspberry Pi throttling status (if applicable), and current weather (cached). Supports macOS and multiple Linux distributions (Debian/Ubuntu, Fedora, Arch, openSUSE). Optionally runs fastfetch for extended system info and displays ASCII art.
### How to Use
```bash
# Run directly
./welcome.sh

# Add to shell profile for automatic login display
echo "~/.config/welcome.sh/../welcome.sh" >> ~/.bashrc
# or simply source it from your .bashrc / .zshrc / .profile
```

No flags -- this is a read-only display script. Behavior is controlled entirely through the config file.

**Prerequisites:** bash, curl (for public IP and weather lookups). Optional: fastfetch, lm-sensors (for CPU temp on x86 Linux).
### What and Where to Tweak
- **Config file** (`~/.config/welcome.sh/config`) -- Source-able bash file that overrides defaults. Supported variables:
  - `SHOW_FASTFETCH=true|false` -- Run fastfetch at startup (default: true)
  - `SHOW_WEATHER=true|false` -- Show weather info (default: true)
  - `SHOW_PUBLIC_IP=true|false` -- Show public IP (default: true)
  - `SHOW_SYSTEM_METRICS=true|false` -- Show memory and top CPU process (default: true)
  - `SHOW_ASCII_ART=true|false` -- Show large ASCII "WELCOME" banner (default: false)
  - `QUIET_MODE=true|false` -- Suppress top-CPU-process line (default: false)
  - `WEATHER_LOCATION=""` -- Location string for wttr.in (default: "Lake+City")
  - `CACHE_TIMEOUT=3600` -- Seconds before cached weather/IP data expires
  - `REQUEST_TIMEOUT=3` -- Seconds before curl requests time out
- **Cache directory** (`~/.cache/welcome.sh/`) -- Stores cached weather and public IP data. Safe to delete to force fresh lookups.
- **Weather location** -- Change `WEATHER_LOCATION` in the config file to your city (use `+` for spaces, e.g., `New+York`).
