# get_expires
## Michal Ferber
## Revised Date: 06/02/2026
### Description
Single-domain expiry lookup against Cloudflare Registrar. Prints the expiration date (ISO 8601) for one domain to stdout.

### How to Use

```bash
export CF_API_TOKEN="your-token"
export CF_ACCOUNT_ID="your-account-id"
./get_expires.sh example.com
```

Output:

```
2025-12-31T00:00:00Z
```

Returns `N/A (not registered with Cloudflare or error)` if the domain isn't on this account.

### Requirements

- `curl`, `jq` installed
- Cloudflare API token with **Registrar (read)** scope

### Pairs with

- [`domains.sh`](domains.md) — bulk CSV refresh
