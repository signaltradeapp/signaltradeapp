#!/usr/bin/env bash
# Pull every fill since the last run (any key). Keeps the cursor in a local file.
# Deduplicate rows by accountId + id: a row can be re-read once fees arrive.
# Usage: ./fills_since_cursor.sh [cursor-file]   (needs jq)
set -euo pipefail
source "$(dirname "$0")/_common.sh"
command -v jq >/dev/null || { echo "this script needs jq" >&2; exit 1; }

CURSOR_FILE="${1:-.sta_fills_cursor}"
CURSOR=$(cat "$CURSOR_FILE" 2>/dev/null || true)

while :; do
  URL="$BASE/fills?limit=1000${CURSOR:+&after=$CURSOR}"
  PAGE=$(curl -sS -H "X-API-Key: $STA_API_KEY" "$URL")
  echo "$PAGE" | jq -c '.data[]'
  NEXT=$(echo "$PAGE" | jq -r '.meta.nextCursor // empty')
  [ -n "$NEXT" ] && CURSOR="$NEXT" && echo "$CURSOR" > "$CURSOR_FILE"
  [ "$(echo "$PAGE" | jq -r '.meta.hasMore')" = "true" ] || break
  sleep 5   # same path at most 12 times a minute
done
