# install
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Installs Unbound DNS resolver and its dependencies on a Debian/Ubuntu system. Creates required directories, copies example configuration files into place (if not already present), fetches initial root hints, installs helper scripts to /usr/local/sbin, and sets up a systemd timer to keep root hints updated. Enables and starts both Unbound and the root-hints timer.
### How to Use
Run from the root of the unbound project directory (where the etc/, scripts/, and systemd/ subdirectories live):
```
sudo bash install.sh
```
Preview what the script would do without making changes:
```
bash install.sh --dry-run
```
Prerequisites: Debian/Ubuntu with apt, sudo privileges, and an active internet connection.
### What and Where to Tweak
- The example config filenames (`lan53.conf.example`, `mykk.foo.conf.example`, `mykk.foo.tsv.sample`) assume a specific zone name. Rename or replace these files in the `etc/unbound/` tree before running.
- Script install paths default to `/usr/local/sbin/`. Change the `install` lines if you prefer a different location.
- The systemd unit files are sourced from `systemd/` in the project directory. Edit them before running to adjust timer schedules.
