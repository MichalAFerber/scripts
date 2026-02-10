#!/bin/bash
# domains.sh - Refresh Domain Expiry Dates from Cloudflare Registrar
#
# Reads a CSV of Cloudflare zones and updates the "expires_at" column by
# querying the Cloudflare Registrar API for each domain.
#
# Usage:
#   export CF_API_TOKEN="your-token"
#   export CF_ACCOUNT_ID="your-account-id"
#   ./domains.sh
#
# Prerequisites:
#   - CF_API_TOKEN  : Cloudflare API token with Registrar read access
#   - CF_ACCOUNT_ID : Your Cloudflare account ID
#   - curl, jq, awk must be installed
#   - Input CSV (cloudflare_zones_with_renewal.csv) must exist in current dir
#
# Output: cloudflare_zones_with_renewal_updated.csv with fresh expiry dates

TOKEN="${CF_API_TOKEN:?Set CF_API_TOKEN env var}"
ACCOUNT_ID="${CF_ACCOUNT_ID:?Set CF_ACCOUNT_ID env var}"

INPUT_CSV="cloudflare_zones_with_renewal.csv"
OUTPUT_CSV="cloudflare_zones_with_renewal_updated.csv"

# Header
head -n 1 "$INPUT_CSV" > "$OUTPUT_CSV"

# Process each line (skip header)
tail -n +2 "$INPUT_CSV" | while IFS= read -r line; do
  # Extract domain (second field)
  domain=$(echo "$line" | awk -F',' '{gsub(/"/, "", $2); print $2}')

  echo "Fetching expires_at for $domain..."
  RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/registrar/domains/$domain" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json")

  NEW_EXPIRES=$(echo "$RESPONSE" | jq -r '.result.expires_at // "N/A"')

  if [[ "$NEW_EXPIRES" != "N/A" && "$NEW_EXPIRES" != "null" ]]; then
    # Robust replacement of last field (handles quoted or unquoted)
    updated_line=$(echo "$line" | sed -E "s/,([^,]*)?$/,\"$NEW_EXPIRES\"/")
    echo "$updated_line" >> "$OUTPUT_CSV"
    echo "Updated $domain → $NEW_EXPIRES"
  else
    echo "$line" >> "$OUTPUT_CSV"
    echo "No date for $domain (not registered with Cloudflare Registrar)"
  fi

  sleep 0.5  # Rate limit safety
done

echo "Done! Check $OUTPUT_CSV — all N/A should now be real dates."