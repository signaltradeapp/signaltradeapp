#!/usr/bin/env bash
# Attach or replace the TP/SL (broker OCO) on an open position (needs a "trade" key).
# Omit a leg to keep it; pass "null" to remove it. Every call places new orders (new ids).
# Usage: ACCOUNT_ID=... ./protect.sh MNQ 21100 20980 [Day|GTC]
set -euo pipefail
source "$(dirname "$0")/_common.sh"
: "${ACCOUNT_ID:?Set ACCOUNT_ID}"

SYMBOL="${1:?symbol}"; TP="${2:?take-profit price or null}"; SL="${3:?stop-loss price or null}"; TIF="${4:-Day}"

curl -sS -X POST "$BASE/accounts/$ACCOUNT_ID/protect" \
  -H "X-API-Key: $STA_API_KEY" -H "Content-Type: application/json" \
  -d "{\"symbol\":\"$SYMBOL\",\"takeProfit\":$TP,\"stopLoss\":$SL,\"timeInForce\":\"$TIF\"}" | pretty
