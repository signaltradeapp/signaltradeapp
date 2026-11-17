#!/usr/bin/env bash
# Move the one working stop of a position through the webhook "movestop" action.
#   export WEBHOOK_TOKEN=...   (from the Signals page)
# Usage:
#   ./webhook_movestop.sh MNQ1! offsetPoints 0      # breakeven (from the BROKER average entry)
#   ./webhook_movestop.sh MNQ1! lockUsd 1740        # lock $1,740 on the whole position
#   ./webhook_movestop.sh MNQ1! price 21050.25      # an exact price
# Refused (stop left untouched) when there is no position, no stop, more than one stop,
# or the new price is at or through the market.
set -euo pipefail
: "${WEBHOOK_TOKEN:?Set WEBHOOK_TOKEN}"
URL="${STA_WEBHOOK_URL:-https://signaltradeapp.com/api/webhook}/$WEBHOOK_TOKEN"

SYMBOL="${1:?symbol, e.g. MNQ1!}"
FIELD="${2:?price | offsetPoints | lockUsd}"
VALUE="${3:?value}"
case "$FIELD" in price|offsetPoints|lockUsd) ;; *) echo "field must be price, offsetPoints or lockUsd" >&2; exit 1;; esac

curl -sS -X POST "$URL" -H "Content-Type: text/plain" \
  --data "{\"action\":\"movestop\",\"symbol\":\"$SYMBOL\",\"$FIELD\":$VALUE}"; echo
# 200 {"success":true,"action":"movestop","symbol":"MNQZ6","orderId":"...","from":...,"price":...,"entry":...}
