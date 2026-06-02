#!/usr/bin/env bash

cat <<'__DOC__'
# sync_folders.py

Basic Two-Way Folder Synchronization using rsync.

Author: Michal A. Ferber
License: MIT
Repo: https://github.com/MichalAFerber/scripts

## Usage

```bash
./sync_folders.sh /mnt/storage1/books /mnt/storage2/books
./sync_folders.sh /mnt/storage1/books /mnt/storage2/books --dry-run
```

- Uses `rsync -av --delete` under the hood.
- Performs **bidirectional sync**.
- Logs output to a timestamped file.

__DOC__

python3 "$(dirname "$0")/sync_folders.py" "$@"
