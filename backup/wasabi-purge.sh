#!/usr/bin/env bash
# wasabi-purge — delete >90d objects + sweep empty dirs
# usage: wasabi-purge <remote:bucket> [extra rclone flags...]
set -euo pipefail
target="$1"; shift
rclone delete "$target" --min-age 90d -v "$@"
rclone rmdirs "$target" --leave-root -v "$@"
