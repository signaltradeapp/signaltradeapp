#!/usr/bin/env bash
# Print the live account stream (Server-Sent Events). Ctrl-C to stop.
# Usage: ./stream.sh [ACCOUNT_ID]        connection status only: ./stream.sh --health
set -euo pipefail
source "$(dirname "$0")/_common.sh"

if [ "${1:-}" = "--health" ]; then
  URL="$BASE/connection-health/stream"
else
  URL="$BASE/stream${1:+?accountId=$1}"
fi
# -N: no buffering. A heartbeat arrives every 15 s; reconnect after 30 s of silence.
curl -sS -N -H "X-API-Key: $STA_API_KEY" -H "Accept: text/event-stream" "$URL"
