#!/usr/bin/env python3
"""
Cloudflare Domain Trace Report

Loops through all domains (zones) across all Cloudflare accounts accessible
by the authenticated user. For each domain, traces four URL variants:
  - http://www.{domain}
  - http://{domain}
  - https://www.{domain}
  - https://{domain}

Outputs a JSON report and a Markdown summary.

Authentication uses a Global API Key + email via environment variables:
  CF_API_KEY   - Your Cloudflare Global API Key
  CF_API_EMAIL - Your Cloudflare account email

Usage:
  export CF_API_KEY="your-global-api-key"
  export CF_API_EMAIL="you@example.com"
  python3 cf_trace_domains.py
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone

CF_API_BASE = "https://api.cloudflare.com/client/v4"
TRACE_URL_TEMPLATES = [
    "http://www.{domain}",
    "http://{domain}",
    "https://www.{domain}",
    "https://{domain}",
]


def get_env_credentials():
    api_key = os.environ.get("CF_API_KEY", "")
    email = os.environ.get("CF_API_EMAIL", "")
    if not api_key or not email:
        print("Error: CF_API_KEY and CF_API_EMAIL environment variables are required.")
        print("  export CF_API_KEY='your-global-api-key'")
        print("  export CF_API_EMAIL='you@example.com'")
        sys.exit(1)
    return api_key, email


def cf_request(path, api_key, email, method="GET", data=None):
    """Make an authenticated request to the Cloudflare API."""
    url = f"{CF_API_BASE}{path}"
    headers = {
        "X-Auth-Key": api_key,
        "X-Auth-Email": email,
        "Content-Type": "application/json",
    }
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        print(f"  API error ({e.code}): {error_body[:200]}")
        return None


def get_all_accounts(api_key, email):
    """Fetch all accounts the user has access to."""
    accounts = []
    page = 1
    while True:
        resp = cf_request(f"/accounts?page={page}&per_page=50", api_key, email)
        if not resp or not resp.get("success"):
            break
        accounts.extend(resp["result"])
        if page >= resp["result_info"]["total_pages"]:
            break
        page += 1
    return accounts


def get_all_zones(api_key, email):
    """Fetch all zones (domains) across all accounts."""
    zones = []
    page = 1
    while True:
        resp = cf_request(f"/zones?page={page}&per_page=50", api_key, email)
        if not resp or not resp.get("success"):
            break
        zones.extend(resp["result"])
        if page >= resp["result_info"]["total_pages"]:
            break
        page += 1
    return zones


def trace_url(account_id, url, api_key, email):
    """Run a Cloudflare trace for a single URL."""
    path = f"/accounts/{account_id}/request-tracer/trace"
    data = {"url": url, "method": "GET"}
    resp = cf_request(path, api_key, email, method="POST", data=data)
    if resp and resp.get("success"):
        return resp["result"]
    return {"error": resp.get("errors", "Unknown error") if resp else "Request failed"}


def summarize_trace(trace_result):
    """Extract a concise summary from a trace result."""
    if "error" in trace_result:
        return {"status_code": None, "matched_rules": [], "error": str(trace_result["error"])}

    status_code = trace_result.get("status_code")
    matched_rules = []

    def walk_trace(items, parent_phase=""):
        for item in items:
            # Track the current phase name for context
            current_phase = parent_phase
            if item.get("public_name"):
                current_phase = item["public_name"]

            if item.get("matched"):
                rule_info = {
                    "step": item.get("step_name", ""),
                    "type": item.get("type", ""),
                    "action": item.get("action", ""),
                    "description": item.get("description", ""),
                    "phase": current_phase,
                }
                if item.get("name"):
                    rule_info["name"] = item["name"]
                if item.get("action_parameter"):
                    rule_info["action_parameter"] = item["action_parameter"]
                if item.get("expression"):
                    rule_info["expression"] = item["expression"]
                # Only include leaf rules (with an action), not container phases/rulesets
                if item.get("action"):
                    matched_rules.append(rule_info)
            # Recurse into nested traces
            if "trace" in item and isinstance(item["trace"], list):
                walk_trace(item["trace"], current_phase)

    walk_trace(trace_result.get("trace", []))
    return {"status_code": status_code, "matched_rules": matched_rules}


def generate_markdown(report, output_path):
    """Generate a Markdown report from the trace results."""
    lines = [
        "# Cloudflare Domain Trace Report",
        "",
        f"**Generated:** {report['generated_at']}  ",
        f"**Total Domains:** {report['total_domains']}  ",
        f"**Total Accounts:** {report['total_accounts']}",
        "",
        "---",
        "",
    ]

    for domain_entry in report["domains"]:
        domain = domain_entry["domain"]
        account = domain_entry["account_name"]
        lines.append(f"## {domain}")
        lines.append(f"**Account:** {account}  ")
        lines.append("")
        lines.append("| URL | Status | Matched Rules | Details |")
        lines.append("|-----|--------|---------------|---------|")

        for trace in domain_entry["traces"]:
            url = trace["url"]
            summary = trace["summary"]
            status = summary.get("status_code", "N/A")
            if summary.get("error"):
                status = "ERROR"
            matched = summary.get("matched_rules", [])
            rule_count = len(matched)

            details_parts = []
            for rule in matched:
                phase = rule.get("phase", "")
                desc = rule.get("description", "")
                action = rule.get("action", "")
                # Build a readable detail: "Phase > action: description"
                if desc and desc != action:
                    label = f"{action}: {desc}" if action else desc
                elif phase:
                    label = f"{phase} ({action})" if action else phase
                else:
                    label = action
                if label:
                    details_parts.append(label)

            details = "; ".join(details_parts) if details_parts else "-"
            if summary.get("error"):
                details = str(summary["error"])[:80]

            lines.append(f"| `{url}` | {status} | {rule_count} | {details} |")

        lines.append("")

    with open(output_path, "w") as f:
        f.write("\n".join(lines))


def generate_csv(report, output_path):
    """Generate a CSV report from the trace results."""
    import csv
    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["domain", "account", "url", "status_code", "matched_rule_count", "actions", "error"])
        for domain_entry in report["domains"]:
            for trace in domain_entry["traces"]:
                summary = trace["summary"]
                action_parts = []
                for r in summary.get("matched_rules", []):
                    phase = r.get("phase", "")
                    desc = r.get("description", "")
                    action = r.get("action", "")
                    if desc and desc != action:
                        action_parts.append(f"{action}: {desc}" if action else desc)
                    elif phase:
                        action_parts.append(f"{phase} ({action})" if action else phase)
                    else:
                        action_parts.append(action)
                actions = "; ".join(action_parts)
                writer.writerow([
                    domain_entry["domain"],
                    domain_entry["account_name"],
                    trace["url"],
                    summary.get("status_code", ""),
                    len(summary.get("matched_rules", [])),
                    actions,
                    summary.get("error", ""),
                ])


def main():
    api_key, email = get_env_credentials()

    print("Fetching accounts...")
    accounts = get_all_accounts(api_key, email)
    account_map = {a["id"]: a["name"] for a in accounts}
    print(f"  Found {len(accounts)} account(s): {', '.join(account_map.values())}")

    print("Fetching zones...")
    zones = get_all_zones(api_key, email)
    active_zones = [z for z in zones if z.get("status") == "active"]
    print(f"  Found {len(zones)} total zone(s), {len(active_zones)} active")

    report = {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "total_domains": len(active_zones),
        "total_accounts": len(accounts),
        "accounts": [{"id": a["id"], "name": a["name"]} for a in accounts],
        "domains": [],
    }

    for i, zone in enumerate(active_zones, 1):
        domain = zone["name"]
        account_id = zone["account"]["id"]
        account_name = zone["account"]["name"]
        print(f"[{i}/{len(active_zones)}] Tracing {domain} ({account_name})...")

        domain_entry = {
            "domain": domain,
            "zone_id": zone["id"],
            "account_id": account_id,
            "account_name": account_name,
            "traces": [],
        }

        for url_template in TRACE_URL_TEMPLATES:
            url = url_template.format(domain=domain)
            trace_result = trace_url(account_id, url, api_key, email)
            summary = summarize_trace(trace_result)
            domain_entry["traces"].append({
                "url": url,
                "summary": summary,
                "raw": trace_result,
            })
            # Small delay to avoid rate limiting
            time.sleep(0.25)

        report["domains"].append(domain_entry)

    # Determine output directory (same as script location)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # Write JSON report (full details including raw trace data)
    json_path = os.path.join(script_dir, f"trace_report_{timestamp}.json")
    with open(json_path, "w") as f:
        json.dump(report, f, indent=2)
    print(f"\nJSON report: {json_path}")

    # Write Markdown summary
    md_path = os.path.join(script_dir, f"trace_report_{timestamp}.md")
    generate_markdown(report, md_path)
    print(f"Markdown report: {md_path}")

    # Write CSV
    csv_path = os.path.join(script_dir, f"trace_report_{timestamp}.csv")
    generate_csv(report, csv_path)
    print(f"CSV report: {csv_path}")

    print(f"\nDone. Traced {len(active_zones)} domains x 4 URLs = {len(active_zones) * 4} total traces.")


if __name__ == "__main__":
    main()
