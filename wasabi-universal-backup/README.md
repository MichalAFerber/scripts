# wasabi-universal-backup

Universal, cross‑platform backup scripts for sending folders to **Wasabi → `ferber-storage`** using **rclone**.
- Works on macOS, Linux (Bash) and Windows (PowerShell).
- CLI‑first, but prompts interactively if arguments are missing.
- **Recursive** transfers with **robust logging** (start/end times, command used, rclone output, errors).
- Flexible **destination subpath** (under `ferber-storage/…`) and **any source** folder.
- Supports **auto‑dated subfolders** and **exclude patterns**.
- No dependency on Cyberduck / Mountain Duck.

> Requires an rclone remote named `wasabi-ferber` pointing at Wasabi (see below).

---

## Quick start

### 1) Install rclone
- **macOS:** `brew install rclone`
- **Linux (Debian/Ubuntu):** `sudo apt-get install rclone` or `curl https://rclone.org/install.sh | sudo bash`
- **Windows:** Install from rclone.org or `winget install rclone.rclone`

### 2) Configure the Wasabi remote
Create a remote named **`wasabi-ferber`**:
```bash
rclone config create wasabi-ferber s3 \
  provider Wasabi \
  access_key_id YOUR_KEY \
  secret_access_key YOUR_SECRET \
  endpoint s3.us-east-1.wasabisys.com
```
> If your bucket region differs, adjust the endpoint accordingly.

Test:
```bash
rclone lsd wasabi-ferber:ferber-storage
```

---

## Usage (Bash)

```bash
./scripts/universal_backup.sh \
  --src "/path/to/folder" \
  --dest-sub "backup-mando/$(date +%F)" \
  --mode copy \
  --excludes ./examples/excludes-common.txt \
  --verify
```

**Auto‑date default:** If you omit `--dest-sub`, it will default to `backup-$(hostname)/$(date +%F)`.

### Common options
- `--mode copy|sync` — `copy` (default) is additive; `sync` mirrors (deletes extras at dest).
- `--excludes PATH` — file with rsync‑style patterns (one per line).
- `--dry-run` — show actions only.
- `--verify` — run `rclone check` after transfer (one‑way, size‑only). Use `--checksum` within the script if you want hashes (slower).
- `--transfers N` / `--checkers N` — concurrency controls.
- `--bwlimit 10M` — throttle bandwidth.
- `--log-dir PATH` — default `~/Logs`.

Logs: `~/Logs/wasabi-backup-YYYYmmdd-HHMMSS.txt`

---

## Usage (PowerShell)

```powershell
.\scripts\universal_backup.ps1 `
  -Src "D:\Media" `
  -DestSub "backup-mando\$(Get-Date -Format yyyy-MM-dd)" `
  -Mode copy `
  -Excludes ".\examples\excludes-common.txt" `
  -Verify
```

**Auto‑date default:** If `-DestSub` is omitted, defaults to `backup-$env:COMPUTERNAME/$(Get-Date -Format yyyy-MM-dd)`.

---

## Exclusions

Use `--excludes` (Bash) / `-Excludes` (PowerShell) to pass a **pattern file**. See [`examples/excludes-common.txt`](examples/excludes-common.txt) for a starter set (thumbs.db, cache dirs, temp files, etc). Patterns are passed through to rclone via `--exclude-from`.

---

## GitHub Actions (optional)

A self‑hosted runner can use this workflow to run scheduled/manual backups with the same scripts. **Note:** Hosted GitHub runners won’t see your local files; use a self‑hosted runner that has access to your data and rclone credentials.

- Edit the workflow inputs (source path, destination subfolder) or call the scripts directly.
- Store rclone config and Wasabi creds on the runner (e.g., in `~/.config/rclone/rclone.conf`).

See [`.github/workflows/backup.yml`](.github/workflows/backup.yml).

---

## Environment defaults

Create a copy of `.env.sample` named `.env` in the repo root to override defaults like log dir, remote name, bucket, transfers/checkers, etc.

---

## License

MIT
