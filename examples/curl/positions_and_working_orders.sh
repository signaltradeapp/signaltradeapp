#!/usr/bin/env bash
# Show open positions and the orders resting at the broker for one account (any key).
# Note: GET /accounts/{id}/orders is TRADE HISTORY; live orders are /working-orders.
# Usage: ACCOUNT_ID=... ./positions_and_working_orders.sh
set -euo pipefail
source "$(dirname "$0")/_common.sh"
: "${ACCOUNT_ID:?Set ACCOUNT_ID}"

echo "# positions"
curl -sS -H "X-API-Key: $STA_API_KEY" "$BASE/accounts/$ACCOUNT_ID/positions" | pretty
echo "# working orders"
curl -sS -H "X-API-Key: $STA_API_KEY" "$BASE/accounts/$ACCOUNT_ID/working-orders" | pretty
