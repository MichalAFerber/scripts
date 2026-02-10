#!/usr/bin/env python3
"""
Cloudflare Domain Redirect Configurator

Reads a CSV of domains and desired redirect behavior, then verifies and
applies the necessary Cloudflare configuration for each domain:

For "root" domains (redirect_to = root):
  - Ensures "Always Use HTTPS" is enabled
  - Ensures a proxied A record for www -> 192.0.2.1 exists
  - Ensures two redirect rules exist (preserving existing rules):
    1. "Redirect from HTTP://WWW to root" - http://www.{domain}/* -> https://{domain}/*
    2. "Redirect from HTTPS://WWW to root" - https://www.{domain}/* -> https://{domain}/*

For cross-domain redirects (redirect_to = another domain):
  - Ensures "Always Use HTTPS" is enabled
  - Ensures a proxied A record for @ -> 192.0.2.1 exists (if not already proxied)
  - Ensures a proxied A record for www -> 192.0.2.1 exists
  - Ensures a single redirect rule exists (preserving existing rules):
    1. Redirects all traffic to https://{new_domain}

Usage:
  export CF_API_KEY="your-global-api-key"
  export CF_API_EMAIL="you@example.com"
  python3 cf_configure_redirects.py --dry-run          # Preview changes
  python3 cf_configure_redirects.py                     # Apply changes
  python3 cf_configure_redirects.py --csv other.csv     # Use a different CSV
"""

import csv
import json
import os
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime

CF_API_BASE = "https://api.cloudflare.com/client/v4"
DUMMY_IP = "192.0.2.1"

# Rule descriptions to identify our managed rules
RULE_HTTP_WWW = "Redirect from HTTP://WWW to root"
RULE_HTTPS_WWW = "Redirect from HTTPS://WWW to root"
RULE_ALL_TO_NEW = "Redirect all traffic to {target}"
# Legacy rule descriptions that should be replaced
LEGACY_RULE_HTTP = "Redirect from HTTP:// to root"
LEGACY_RULE_HTTPS = "Redirect from HTTPS:// to root"


def get_env_credentials():
    api_key = os.environ.get("CF_API_KEY", "")
    email = os.environ.get("CF_API_EMAIL", "")
    if not api_key or not email:
        print("Error: CF_API_KEY and CF_API_EMAIL environment variables are required.")
        sys.exit(1)
    return api_key, email


def cf_request(path, api_key, email, method="GET", data=None):
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
        return {"success": False, "errors": [{"message": f"HTTP {e.code}: {error_body[:200]}"}]}


def get_zone_id(domain, api_key, email):
    resp = cf_request(f"/zones?name={domain}&status=active", api_key, email)
    if resp and resp.get("success") and resp["result"]:
        return resp["result"][0]["id"]
    return None


def get_always_use_https(zone_id, api_key, email):
    resp = cf_request(f"/zones/{zone_id}/settings/always_use_https", api_key, email)
    if resp and resp.get("success"):
        return resp["result"]["value"] == "on"
    return None


def set_always_use_https(zone_id, api_key, email, dry_run=False):
    if dry_run:
        return True
    resp = cf_request(f"/zones/{zone_id}/settings/always_use_https", api_key, email,
                      method="PATCH", data={"value": "on"})
    return resp and resp.get("success")


def get_dns_records(zone_id, api_key, email, record_type=None, name=None):
    params = []
    if record_type:
        params.append(f"type={record_type}")
    if name:
        params.append(f"name={name}")
    query = "&".join(params)
    path = f"/zones/{zone_id}/dns_records"
    if query:
        path += f"?{query}"
    resp = cf_request(path, api_key, email)
    if resp and resp.get("success"):
        return resp["result"]
    return []


def create_dns_record(zone_id, record_type, name, content, proxied, api_key, email, dry_run=False):
    if dry_run:
        return True
    data = {"type": record_type, "name": name, "content": content, "proxied": proxied, "ttl": 1}
    resp = cf_request(f"/zones/{zone_id}/dns_records", api_key, email, method="POST", data=data)
    return resp and resp.get("success")


def update_dns_record(zone_id, record_id, record_type, name, content, proxied, api_key, email, dry_run=False):
    if dry_run:
        return True
    data = {"type": record_type, "name": name, "content": content, "proxied": proxied, "ttl": 1}
    resp = cf_request(f"/zones/{zone_id}/dns_records/{record_id}", api_key, email, method="PATCH", data=data)
    return resp and resp.get("success")


def get_redirect_ruleset(zone_id, api_key, email):
    """Get the zone's Single Redirects ruleset and its rules."""
    resp = cf_request(f"/zones/{zone_id}/rulesets", api_key, email)
    if not resp or not resp.get("success"):
        return None, []
    for rs in resp["result"]:
        if rs.get("phase") == "http_request_dynamic_redirect" and rs.get("kind") == "zone":
            # Fetch full ruleset with rules
            detail = cf_request(f"/zones/{zone_id}/rulesets/{rs['id']}", api_key, email)
            if detail and detail.get("success"):
                return rs["id"], detail["result"].get("rules", [])
    return None, []


def create_redirect_ruleset(zone_id, rules, api_key, email, dry_run=False):
    """Create a new Single Redirects ruleset for the zone."""
    if dry_run:
        return True
    data = {
        "name": "default",
        "kind": "zone",
        "phase": "http_request_dynamic_redirect",
        "rules": rules,
    }
    resp = cf_request(f"/zones/{zone_id}/rulesets", api_key, email, method="POST", data=data)
    return resp and resp.get("success")


def add_rule_to_ruleset(zone_id, ruleset_id, rule, api_key, email, dry_run=False):
    """Add a single rule to an existing ruleset."""
    if dry_run:
        return True
    resp = cf_request(f"/zones/{zone_id}/rulesets/{ruleset_id}/rules", api_key, email,
                      method="POST", data=rule)
    return resp and resp.get("success")


def delete_rule_from_ruleset(zone_id, ruleset_id, rule_id, api_key, email, dry_run=False):
    """Delete a single rule from a ruleset."""
    if dry_run:
        return True
    resp = cf_request(f"/zones/{zone_id}/rulesets/{ruleset_id}/rules/{rule_id}", api_key, email,
                      method="DELETE")
    return resp and resp.get("success")


def build_www_redirect_rule(domain, scheme):
    """Build a redirect rule for {scheme}://www.{domain}/* -> https://{domain}/*"""
    scheme_label = "HTTP" if scheme == "http" else "HTTPS"
    return {
        "description": f"Redirect from {scheme_label}://WWW to root",
        "expression": f'(http.request.full_uri wildcard r"{scheme}://www.{domain}*")',
        "action": "redirect",
        "action_parameters": {
            "from_value": {
                "status_code": 301,
                "target_url": {
                    "expression": f'wildcard_replace(http.request.full_uri, r"{scheme}://www.*", r"https://${{1}}")'
                },
                "preserve_query_string": True,
            }
        },
        "enabled": True,
    }


def build_cross_domain_redirect_rule(domain, target_domain):
    """Build a redirect rule that sends all traffic to https://{target_domain}"""
    return {
        "description": f"Redirect all traffic to {target_domain}",
        "expression": "true",
        "action": "redirect",
        "action_parameters": {
            "from_value": {
                "status_code": 301,
                "target_url": {
                    "value": f"https://{target_domain}"
                },
                "preserve_query_string": False,
            }
        },
        "enabled": True,
    }


def is_our_rule(rule, domain, mode):
    """Check if a rule is one we manage (so we can update/replace it)."""
    desc = rule.get("description", "")
    if mode == "root":
        return desc in (RULE_HTTP_WWW, RULE_HTTPS_WWW, LEGACY_RULE_HTTP, LEGACY_RULE_HTTPS)
    else:
        return desc.startswith("Redirect all traffic to ") or desc in (LEGACY_RULE_HTTP, LEGACY_RULE_HTTPS)


def configure_root_domain(domain, zone_id, api_key, email, dry_run=False):
    """Configure a domain for www -> root redirects."""
    changes = []

    # 1. Check Always Use HTTPS
    https_on = get_always_use_https(zone_id, api_key, email)
    if not https_on:
        changes.append("Enable Always Use HTTPS")
        if not dry_run:
            set_always_use_https(zone_id, api_key, email)
    time.sleep(0.25)

    # 2. Check www DNS record
    www_records = get_dns_records(zone_id, api_key, email, name=f"www.{domain}")
    www_a = [r for r in www_records if r["type"] == "A"]
    time.sleep(0.25)

    if not www_a:
        changes.append(f"Create DNS A record: www.{domain} -> {DUMMY_IP} (proxied)")
        if not dry_run:
            create_dns_record(zone_id, "A", f"www.{domain}", DUMMY_IP, True, api_key, email)
        time.sleep(0.25)
    else:
        rec = www_a[0]
        if rec["content"] != DUMMY_IP or not rec["proxied"]:
            changes.append(f"Update DNS A record: www.{domain} -> {DUMMY_IP} (proxied) [was {rec['content']}, proxied={rec['proxied']}]")
            if not dry_run:
                update_dns_record(zone_id, rec["id"], "A", f"www.{domain}", DUMMY_IP, True, api_key, email)
            time.sleep(0.25)

    # 3. Check redirect rules
    ruleset_id, existing_rules = get_redirect_ruleset(zone_id, api_key, email)
    time.sleep(0.25)

    # Identify our managed rules vs. other rules we must preserve
    legacy_rules = []
    has_http_www = False
    has_https_www = False

    for rule in existing_rules:
        desc = rule.get("description", "")
        expr = rule.get("expression", "")
        # Match by description OR by expression pattern
        is_http_www = (desc == RULE_HTTP_WWW
                       or f'http://www.{domain}' in expr
                       or (rule.get("action") == "redirect" and 'http://www.' in expr and 'https://www.' not in expr))
        is_https_www = (desc == RULE_HTTPS_WWW
                        or (rule.get("action") == "redirect" and 'https://www.' in expr and 'http://www.' not in expr)
                        or (desc == "Redirect from WWW to root" and 'https://www.' in expr))

        if is_http_www:
            has_http_www = True
        elif is_https_www:
            has_https_www = True
        elif desc in (LEGACY_RULE_HTTP, LEGACY_RULE_HTTPS):
            legacy_rules.append(rule)

    # Remove legacy rules
    for rule in legacy_rules:
        changes.append(f"Remove legacy rule: \"{rule['description']}\" (id: {rule['id']})")
        if not dry_run and ruleset_id:
            delete_rule_from_ruleset(zone_id, ruleset_id, rule["id"], api_key, email)
            time.sleep(0.25)

    # Add missing rules
    rules_to_add = []
    if not has_http_www:
        rule = build_www_redirect_rule(domain, "http")
        rules_to_add.append(rule)
        changes.append(f"Add rule: \"{RULE_HTTP_WWW}\"")
    if not has_https_www:
        rule = build_www_redirect_rule(domain, "https")
        rules_to_add.append(rule)
        changes.append(f"Add rule: \"{RULE_HTTPS_WWW}\"")

    if rules_to_add:
        if ruleset_id:
            for rule in rules_to_add:
                if not dry_run:
                    add_rule_to_ruleset(zone_id, ruleset_id, rule, api_key, email)
                    time.sleep(0.25)
        else:
            # No ruleset exists yet, create one
            changes[-len(rules_to_add)] = changes[-len(rules_to_add)].replace("Add rule", "Create ruleset with rule")
            if not dry_run:
                create_redirect_ruleset(zone_id, rules_to_add, api_key, email)
                time.sleep(0.25)

    return changes


def configure_cross_domain(domain, target_domain, zone_id, api_key, email, dry_run=False):
    """Configure a domain to redirect all traffic to another domain."""
    changes = []

    # 1. Check Always Use HTTPS
    https_on = get_always_use_https(zone_id, api_key, email)
    if not https_on:
        changes.append("Enable Always Use HTTPS")
        if not dry_run:
            set_always_use_https(zone_id, api_key, email)
    time.sleep(0.25)

    # 2. Check root A record exists and is proxied
    root_records = get_dns_records(zone_id, api_key, email, record_type="A", name=domain)
    time.sleep(0.25)
    if not root_records:
        changes.append(f"Create DNS A record: {domain} -> {DUMMY_IP} (proxied)")
        if not dry_run:
            create_dns_record(zone_id, "A", domain, DUMMY_IP, True, api_key, email)
        time.sleep(0.25)
    else:
        rec = root_records[0]
        if not rec["proxied"]:
            changes.append(f"Update DNS A record: {domain} -> proxied [was proxied={rec['proxied']}]")
            if not dry_run:
                update_dns_record(zone_id, rec["id"], "A", domain, rec["content"], True, api_key, email)
            time.sleep(0.25)

    # 3. Check www DNS record
    www_records = get_dns_records(zone_id, api_key, email, name=f"www.{domain}")
    www_a = [r for r in www_records if r["type"] == "A"]
    time.sleep(0.25)

    if not www_a:
        changes.append(f"Create DNS A record: www.{domain} -> {DUMMY_IP} (proxied)")
        if not dry_run:
            create_dns_record(zone_id, "A", f"www.{domain}", DUMMY_IP, True, api_key, email)
        time.sleep(0.25)
    else:
        rec = www_a[0]
        if rec["content"] != DUMMY_IP or not rec["proxied"]:
            changes.append(f"Update DNS A record: www.{domain} -> {DUMMY_IP} (proxied) [was {rec['content']}, proxied={rec['proxied']}]")
            if not dry_run:
                update_dns_record(zone_id, rec["id"], "A", f"www.{domain}", DUMMY_IP, True, api_key, email)
            time.sleep(0.25)

    # 4. Check redirect rules
    ruleset_id, existing_rules = get_redirect_ruleset(zone_id, api_key, email)
    time.sleep(0.25)

    expected_desc = f"Redirect all traffic to {target_domain}"
    has_correct_rule = False
    legacy_rules = []

    for rule in existing_rules:
        desc = rule.get("description", "")
        # Check if the rule already redirects to the correct target (by action_parameters or description)
        action_params = rule.get("action_parameters", {}) or rule.get("action_parameter", {})
        target_url = ""
        from_value = action_params.get("from_value", {})
        if from_value:
            tv = from_value.get("target_url", {})
            target_url = tv.get("value", "")

        if desc == expected_desc or target_url == f"https://{target_domain}":
            has_correct_rule = True
        elif desc in (LEGACY_RULE_HTTP, LEGACY_RULE_HTTPS, RULE_HTTP_WWW, RULE_HTTPS_WWW):
            legacy_rules.append(rule)
        elif desc.startswith("Redirect all traffic to ") and desc != expected_desc:
            legacy_rules.append(rule)

    # Remove legacy/wrong rules
    for rule in legacy_rules:
        changes.append(f"Remove rule: \"{rule['description']}\" (id: {rule['id']})")
        if not dry_run and ruleset_id:
            delete_rule_from_ruleset(zone_id, ruleset_id, rule["id"], api_key, email)
            time.sleep(0.25)

    # Add the cross-domain redirect if missing
    if not has_correct_rule:
        new_rule = build_cross_domain_redirect_rule(domain, target_domain)
        changes.append(f"Add rule: \"{expected_desc}\"")
        if not dry_run:
            if ruleset_id:
                add_rule_to_ruleset(zone_id, ruleset_id, new_rule, api_key, email)
            else:
                create_redirect_ruleset(zone_id, [new_rule], api_key, email)
            time.sleep(0.25)

    return changes


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Configure Cloudflare domain redirects from CSV")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without applying them")
    parser.add_argument("--csv", default=None, help="Path to CSV file (default: domains_to_configure.csv)")
    args = parser.parse_args()

    api_key, email = get_env_credentials()
    dry_run = args.dry_run

    csv_path = args.csv or os.path.join(os.path.dirname(os.path.abspath(__file__)), "domains_to_configure.csv")
    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found: {csv_path}")
        sys.exit(1)

    # Read CSV
    entries = []
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            domain = row["domain"].strip()
            redirect_to = row["redirect_to"].strip()
            if domain and redirect_to:
                entries.append((domain, redirect_to))

    if dry_run:
        print("=" * 60)
        print("  DRY RUN — No changes will be made")
        print("=" * 60)
    else:
        print("=" * 60)
        print("  APPLYING CHANGES")
        print("=" * 60)

    print(f"\nProcessing {len(entries)} domains...\n")

    report = []
    for i, (domain, redirect_to) in enumerate(entries, 1):
        mode = "root" if redirect_to == "root" else "cross-domain"
        target = domain if mode == "root" else redirect_to
        print(f"[{i}/{len(entries)}] {domain} -> {'root (self)' if mode == 'root' else redirect_to}")

        # Look up zone — for subdomains, we'd need the parent zone,
        # but we've excluded subdomains from this CSV
        zone_id = get_zone_id(domain, api_key, email)
        if not zone_id:
            print(f"  ERROR: Zone not found for {domain}")
            report.append({"domain": domain, "redirect_to": redirect_to, "status": "ERROR", "changes": ["Zone not found"]})
            continue
        time.sleep(0.25)

        if mode == "root":
            changes = configure_root_domain(domain, zone_id, api_key, email, dry_run)
        else:
            changes = configure_cross_domain(domain, redirect_to, zone_id, api_key, email, dry_run)

        if changes:
            for c in changes:
                print(f"  {'[DRY RUN] ' if dry_run else ''}  {c}")
        else:
            print(f"  No changes needed")

        report.append({
            "domain": domain,
            "redirect_to": redirect_to,
            "status": "OK" if not changes else ("WOULD CHANGE" if dry_run else "CHANGED"),
            "changes": changes if changes else ["Already configured correctly"],
        })

    # Write report
    script_dir = os.path.dirname(os.path.abspath(__file__))
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    mode_label = "dryrun" if dry_run else "applied"
    report_path = os.path.join(script_dir, f"redirect_config_{mode_label}_{timestamp}.json")
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)
    print(f"\nReport: {report_path}")

    # Summary
    no_change = sum(1 for r in report if "Already configured correctly" in r["changes"])
    changed = sum(1 for r in report if r["status"] in ("CHANGED", "WOULD CHANGE"))
    errors = sum(1 for r in report if r["status"] == "ERROR")
    print(f"\nSummary: {no_change} already OK, {changed} {'would change' if dry_run else 'changed'}, {errors} errors")


if __name__ == "__main__":
    main()
