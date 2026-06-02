# domains
## Michal Ferber
## Revised Date: 06/02/2026
### Description
Bulk-refreshes the `expires_at` column of a CSV of Cloudflare-registrar zones. Reads `cloudflare_zones_with_renewal.csv`, queries Cloudflare Registrar's API for each domain, and writes `cloudflare_zones_with_renewal_updated.csv` with fresh expiry dates.

### How to Use

```bash
export CF_API_TOKEN="your-token"           # Cloudflare API token w/ Registrar read
export CF_ACCOUNT_ID="your-account-id"
./domains.sh
```

Input CSV format (must have headers; domain in column 2):

```csv
zone_id,domain,expires_at
abc123,example.com,2025-01-01
```

Output: `cloudflare_zones_with_renewal_updated.csv` with refreshed dates.

### Requirements

- `curl`, `jq`, `awk` installed
- Cloudflare API token with **Registrar (read)** scope
- Account ID from Cloudflare dashboard

### Pairs with

- [`get_expires.sh`](get_expires.md) — single-domain lookup
- [`cf_trace_domains.py`](cf_trace_domains.md) — trace domains across all accounts
