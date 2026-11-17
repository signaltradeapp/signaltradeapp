#!/usr/bin/env bash
# List your connected accounts (any key). Use the "id" field as ACCOUNT_ID elsewhere.
# Usage: ./list_accounts.sh
set -euo pipefail
source "$(dirname "$0")/_common.sh"

curl -sS -H "X-API-Key: $STA_API_KEY" "$BASE/accounts" | pretty
