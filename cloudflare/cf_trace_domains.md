# cf_trace_domains
## Michal Ferber
## Revised Date: 03/27/2026
### Description
Traces all active domains (zones) across every Cloudflare account accessible by the authenticated user. For each domain, it sends four URL variants (http://www, http://, https://www, https://) through Cloudflare's Request Tracer API and collects the results. It then outputs a full JSON report with raw trace data, a Markdown summary table, and a CSV file -- all timestamped and saved alongside the script.
### How to Use
Prerequisites: Python 3.6+, a Cloudflare Global API Key and the associated account email.

```bash
export CF_API_KEY="your-global-api-key"
export CF_API_EMAIL="you@example.com"
python3 cf_trace_domains.py
```

No flags are required. The script automatically paginates through all accounts and zones. Output files (JSON, Markdown, CSV) are written to the same directory as the script with a `trace_report_YYYYMMDD_HHMMSS` naming pattern.
### What and Where to Tweak
- `CF_API_BASE` (line 32) -- Change if using a different Cloudflare API endpoint.
- `TRACE_URL_TEMPLATES` (lines 33-38) -- Add or remove URL variants to trace (e.g., add subdomains or specific paths).
- `time.sleep(0.25)` calls throughout -- Adjust the delay between API calls if you hit rate limits or want faster execution.
- Output directory defaults to the script's own directory. To change it, modify the `script_dir` variable in `main()`.
