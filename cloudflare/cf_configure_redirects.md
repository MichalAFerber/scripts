# cf_configure_redirects
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Reads a CSV file listing domains and their desired redirect behavior, then configures each domain's Cloudflare zone accordingly. For domains redirecting www to root, it enables "Always Use HTTPS," creates a proxied www A record pointing to 192.0.2.1, and adds redirect rules for both HTTP and HTTPS www traffic. For cross-domain redirects, it additionally ensures the root A record is proxied and creates a catch-all 301 redirect to the target domain. Legacy redirect rules are automatically detected and replaced.
### How to Use
Prerequisites: Python 3.6+, a Cloudflare Global API Key and the associated account email, and a CSV file with `domain` and `redirect_to` columns.

CSV format example:
```
domain,redirect_to
example.com,root
old-site.com,new-site.com
```

Use `root` as the `redirect_to` value to redirect www to the bare domain. Use another domain name to redirect all traffic there.

```bash
export CF_API_KEY="your-global-api-key"
export CF_API_EMAIL="you@example.com"

# Preview what would change (no modifications made)
python3 cf_configure_redirects.py --dry-run

# Apply changes
python3 cf_configure_redirects.py

# Use a specific CSV file
python3 cf_configure_redirects.py --csv /path/to/my_domains.csv
```

A JSON report is written after each run with a filename like `redirect_config_dryrun_YYYYMMDD_HHMMSS.json` or `redirect_config_applied_YYYYMMDD_HHMMSS.json`.
### What and Where to Tweak
- `DUMMY_IP` (line 40) -- The placeholder IP used for proxied A records (default: 192.0.2.1, a documentation-reserved address). Change only if your setup requires a different dummy target.
- `--csv` flag -- Defaults to `domains_to_configure.csv` in the same directory as the script. Point it at your own CSV file.
- `time.sleep(0.25)` calls throughout -- Adjust API call delays to manage Cloudflare rate limits.
- Rule description constants (`RULE_HTTP_WWW`, `RULE_HTTPS_WWW`, `LEGACY_RULE_HTTP`, `LEGACY_RULE_HTTPS`) at the top of the file -- These are used to identify managed vs. user-created rules. Only change these if you have renamed rules in Cloudflare manually.
- Output directory defaults to the script's own directory. To change it, modify the `script_dir` variable in `main()`.
