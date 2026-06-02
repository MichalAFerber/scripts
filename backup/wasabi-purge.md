# wasabi-purge
## Michal Ferber
## Revised Date: 06/02/2026
### Description
Lightweight wrapper that bundles `rclone delete --min-age 90d` with `rclone rmdirs --leave-root` so you can't forget the second half. `rclone delete` removes objects but leaves zero-byte directory-marker junk behind (those trailing-slash placeholder objects GUIs and WebDAV clients scatter around); only `rclone rmdirs` hunts them down. Run them as a pair, always.

Pairs with Wasabi's 90-day minimum storage charge — only objects older than 90 days are removed, so cleanup never costs you Timed-Deleted-Storage penalties.

### How to Use

```bash
# Purge a scratch bucket (us-east-1)
wasabi-purge wasabi:ferber-storage

# Purge a central-region replica
wasabi-purge wasabi-central:ferber-storage-replicated

# Dry-run first (recommended)
wasabi-purge wasabi:ferber-storage --dry-run

# Any extra rclone flags pass through to BOTH commands
wasabi-purge wasabi:ferber-storage --transfers=16 --checkers=32
```

### Arguments

- `<remote:bucket>` *(required)* — rclone remote and bucket, e.g. `wasabi:ferber-storage`
- `[extra rclone flags...]` *(optional)* — anything you pass after the target is forwarded to both `rclone delete` AND `rclone rmdirs`

### What it runs

```bash
rclone delete  "$target" --min-age 90d -v "$@"
rclone rmdirs  "$target" --leave-root -v "$@"
```

`--leave-root` keeps the bucket itself from getting pruned when it empties out. Don't omit it (the script handles it for you).

### Requirements

- `rclone` installed and configured with the appropriate Wasabi remote(s) — see [`rclone-wasabi-ferber-storage.md`](rclone-wasabi-ferber-storage.md) for setup.
- Target bucket should be a **scratch** bucket (90d expiry policy). **Never** run this against PBS / Immich / WebDAV buckets — those are app-owned and would get corrupted (see `Intranet/Wasabi/index.md` cardinal rule).

### Safe targets (per the Wasabi runbook)

| Bucket | Region | Safe to wasabi-purge? |
|---|---|---|
| `ferber-storage` | us-east-1 | ✅ yes (scratch, 90d expiry) |
| `ferber-storage-replicated` | us-central-1 | ✅ yes (scratch replica) |
| `ferber-logs` | us-east-1 | ✅ yes (rolling logs) |
| `ferber-pbs` / `-replicated` | — | ❌ **never** (PBS owns it) |
| `ferber-share` | us-east-1 | ❌ **never** (PingVin owns it) |
| `ferber-immich` / `-replicated` | — | ❌ **never** (Immich owns it) |
| `ferber-webdav` | us-east-1 | ❌ **never** (persistent drive) |

### Notes

- The script is intentionally minimal — no dry-run flag of its own; pass `--dry-run` to forward it to rclone.
- For the full Wasabi operational reference, see `Intranet/Wasabi/index.md` in the Obsidian vault.
