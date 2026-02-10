#!/bin/bash
# get_expires.sh - Look Up a Single Domain's Expiry Date via Cloudflare Registrar
#
# Quick lookup tool that queries the Cloudflare Registrar API for one domain's
# expiration date and prints it to stdout.
#
# Usage:
#   export CF_API_TOKEN="your-token"
#   export CF_ACCOUNT_ID="your-account-id"
#   ./get_expires.sh example.com
#
# Prerequisites:
#   - CF_API_TOKEN  : Cloudflare API token with Registrar read access
#   - CF_ACCOUNT_ID : Your Cloudflare account ID
#   - curl, jq must be installed

if [ -z "$1" ]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

DOMAIN="$1"
ACCOUNT_ID="${CF_ACCOUNT_ID:?Set CF_ACCOUNT_ID env var}"
TOKEN="${CF_API_TOKEN:?Set CF_API_TOKEN env var}"

curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/registrar/domains/$DOMAIN" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result.expires_at // "N/A (not registered with Cloudflare or error)"'