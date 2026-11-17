#!/usr/bin/env bash
# Reprice one resting order, e.g. move a stop (needs a "trade" key). Size is kept.
# Read the CURRENT id from positions_and_working_orders.sh first: on Tradovate a bracket
# leg gets a new id after its first move, on Rithmic every move gives a new id.
# Usage: ACCOUNT_ID=... ./move_order.sh ORDER_ID NEW_PRICE
set -euo pipefail
source "$(dirname "$0")/_common.sh"
: "${ACCOUNT_ID:?Set ACCOUNT_ID}"

ORDER_ID="${1:?order id from working-orders}"
PRICE="${2:?new price}"

curl -sS -X PUT "$BASE/accounts/$ACCOUNT_ID/orders/$ORDER_ID" \
  -H "X-API-Key: $STA_API_KEY" -H "Content-Type: application/json" \
  -d "{\"price\":$PRICE}" | pretty
# {"data":{"success":true}}                  Tradovate: repriced in place
# {"data":{"success":true,"replaced":true}}  re-placed under a new id: re-read working-orders
