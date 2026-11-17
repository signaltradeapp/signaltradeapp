#!/usr/bin/env bash
# Realized P&L per trading day, total and per account (any key).
# Usage: ./daily_pnl.sh [FROM YYYY-MM-DD] [TO YYYY-MM-DD]
set -euo pipefail
source "$(dirname "$0")/_common.sh"

QS=""
[ $# -ge 1 ] && QS="?from=$1"
[ $# -ge 2 ] && QS="$QS&to=$2"
curl -sS -H "X-API-Key: $STA_API_KEY" "$BASE/pnl/daily$QS" | pretty
