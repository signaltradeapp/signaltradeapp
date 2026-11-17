#!/usr/bin/env bash
# Place a market order with a take-profit / stop-loss bracket (needs a "trade" key).
# An Idempotency-Key makes a retry of this exact request safe: it returns the first answer.
# Usage: ACCOUNT_ID=... ./place_bracket_order.sh MNQ Buy 1 21050 20970
set -euo pipefail
source "$(dirname "$0")/_common.sh"
: "${ACCOUNT_ID:?Set ACCOUNT_ID}"

SYMBOL="${1:?symbol, e.g. MNQ}"
ACTION="${2:?Buy or Sell}"
QTY="${3:?qty}"
TP="${4:?take-profit price}"
SL="${5:?stop-loss price}"
IDEMPOTENCY_KEY="${IDEMPOTENCY_KEY:-order-$(date +%s)-$RANDOM}"

curl -sS -X POST "$BASE/accounts/$ACCOUNT_ID/orders" \
  -H "X-API-Key: $STA_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $IDEMPOTENCY_KEY" \
  -d "{\"symbol\":\"$SYMBOL\",\"action\":\"$ACTION\",\"qty\":$QTY,\"orderType\":\"Market\",\"takeProfit\":$TP,\"stopLoss\":$SL}" \
  | pretty
# 201 {"data":{"orderId":"..."}}           placed
# 409 BRACKET_INCOMPLETE                    entry placed, a leg refused: check the account, do not resend
# 422 BROKER_ORDER_REJECTED                 the broker said no; the message says why
