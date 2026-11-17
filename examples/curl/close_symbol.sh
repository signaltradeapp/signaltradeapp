#!/usr/bin/env bash
# Close one symbol and cancel its working orders (needs a "trade" key). Other symbols stay.
# Optional guard: only close if the position is still SIDE QTY @ AVG (else 409 POSITION_CHANGED).
# Usage: ACCOUNT_ID=... ./close_symbol.sh MNQ [LONG 2 21020.0]
set -euo pipefail
source "$(dirname "$0")/_common.sh"
: "${ACCOUNT_ID:?Set ACCOUNT_ID}"

SYMBOL="${1:?symbol}"
if [ $# -ge 4 ]; then
  BODY="{\"symbol\":\"$SYMBOL\",\"expected\":{\"side\":\"$2\",\"qty\":$3,\"avgPrice\":$4}}"
else
  BODY="{\"symbol\":\"$SYMBOL\"}"
fi

curl -sS -X POST "$BASE/accounts/$ACCOUNT_ID/positions/close" \
  -H "X-API-Key: $STA_API_KEY" -H "Content-Type: application/json" -d "$BODY" | pretty
