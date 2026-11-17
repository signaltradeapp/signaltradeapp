#!/usr/bin/env bash
# Place a limit entry, wait, and cancel it if it is still working (needs a "trade" key).
# Usage: ACCOUNT_ID=... ./place_limit_then_cancel.sh MNQ Buy 1 21000 60
set -euo pipefail
source "$(dirname "$0")/_common.sh"
: "${ACCOUNT_ID:?Set ACCOUNT_ID}"
command -v jq >/dev/null || { echo "this script needs jq" >&2; exit 1; }

SYMBOL="${1:?symbol}"; ACTION="${2:?Buy or Sell}"; QTY="${3:?qty}"; PRICE="${4:?limit price}"; WAIT="${5:-60}"

ORDER_ID=$(curl -sS -X POST "$BASE/accounts/$ACCOUNT_ID/orders" \
  -H "X-API-Key: $STA_API_KEY" -H "Content-Type: application/json" \
  -H "Idempotency-Key: limit-$(date +%s)-$RANDOM" \
  -d "{\"symbol\":\"$SYMBOL\",\"action\":\"$ACTION\",\"qty\":$QTY,\"orderType\":\"Limit\",\"price\":$PRICE}" \
  | jq -r '.data.orderId // empty')
[ -n "$ORDER_ID" ] || { echo "order was not placed" >&2; exit 1; }
echo "placed $ORDER_ID, waiting ${WAIT}s"
sleep "$WAIT"

STILL_WORKING=$(curl -sS -H "X-API-Key: $STA_API_KEY" "$BASE/accounts/$ACCOUNT_ID/working-orders" \
  | jq --arg id "$ORDER_ID" '[.data[] | select((.id|tostring) == $id)] | length')
if [ "$STILL_WORKING" = "0" ]; then
  echo "order $ORDER_ID is no longer working (filled or cancelled)"; exit 0
fi

# 200 cancelled | 409 CANCEL_REJECTED = it filled meanwhile, do not retry | 503 = retry
curl -sS -X DELETE -H "X-API-Key: $STA_API_KEY" "$BASE/accounts/$ACCOUNT_ID/orders/$ORDER_ID" | pretty
