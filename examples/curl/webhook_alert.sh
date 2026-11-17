#!/usr/bin/env bash
# Send a webhook payload by hand, exactly as a TradingView alert would.
#   export WEBHOOK_TOKEN=...   (from the Signals page; it is the only credential, keep it secret)
# Usage: ./webhook_alert.sh '{"action":"buy","symbol":"MNQ1!","qty":1}'
set -euo pipefail
: "${WEBHOOK_TOKEN:?Set WEBHOOK_TOKEN}"
URL="${STA_WEBHOOK_URL:-https://signaltradeapp.com/api/webhook}/$WEBHOOK_TOKEN"
PAYLOAD="${1:?JSON payload}"

curl -sS -X POST "$URL" -H "Content-Type: text/plain" --data "$PAYLOAD"; echo
# Examples:
#   '{"action":"buy","symbol":"MNQ1!","qty":2,"takeProfit":21050,"stopLoss":20970}'
#   '{"action":"close","symbol":"MNQ1!","percent":50}'
#   '{"action":"cancel","symbol":"MNQ1!"}'
#   '{"action":"close"}'      <- flattens the WHOLE account
