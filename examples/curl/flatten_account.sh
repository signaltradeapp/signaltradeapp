#!/usr/bin/env bash
# Flatten the WHOLE account: close every position, cancel resting orders (needs a "trade" key).
# Usage: ACCOUNT_ID=... ./flatten_account.sh
set -euo pipefail
source "$(dirname "$0")/_common.sh"
: "${ACCOUNT_ID:?Set ACCOUNT_ID}"

curl -sS -X DELETE -H "X-API-Key: $STA_API_KEY" "$BASE/accounts/$ACCOUNT_ID/positions" | pretty
