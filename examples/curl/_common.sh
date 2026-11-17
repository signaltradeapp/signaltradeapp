# Shared settings for the Signal Trade App curl examples. Sourced by the other scripts.
#
#   export STA_API_KEY=ts_live_xxx        # from the API Keys page (never commit it)
#   export ACCOUNT_ID=...                 # an "id" from list_accounts.sh
#   export STA_BASE_URL=...               # optional, defaults to production
#
# Requires: curl. jq is optional (used only to pretty-print).

: "${STA_API_KEY:?Set STA_API_KEY to your API key (ts_live_...)}"
BASE="${STA_BASE_URL:-https://signaltradeapp.com/api/v1}"

pretty() {
  if command -v jq >/dev/null 2>&1; then jq .; else cat; echo; fi
}
