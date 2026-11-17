# REST API v1

Base URL:

```
https://signaltradeapp.com/api/v1
```

All requests and responses are JSON. Interactive reference: [signaltradeapp.com/api/docs](https://signaltradeapp.com/api/docs) (OpenAPI JSON at `/api/docs.json`).

- [Authentication and scopes](#authentication-and-scopes)
- [Plan](#plan)
- [Rate limits](#rate-limits)
- [Idempotency](#idempotency)
- [Errors](#errors)
- [Symbols](#symbols)
- [Order ids](#order-ids)
- Endpoints: [accounts](#accounts) · [positions](#positions) · [orders](#orders) · [protection](#protection) · [risk](#risk) · [fills and P&L](#fills-and-pl) · [groups, connections, copies, user](#groups-connections-copies-user) · [streams](#streams) · [market data](#market-data) · [strategies (beta)](#strategies-beta)

## Authentication and scopes

Send your key in the `X-API-Key` header on every request:

```bash
curl -H "X-API-Key: ts_live_xxx" https://signaltradeapp.com/api/v1/accounts
```

- Create keys on the **API Keys** page (`/api-keys`). Keys start with `ts_live_`. The full key is shown **once**, when you create it. Store it in an environment variable or a secret manager, never in code.
- A key does not expire. **Revoke** it on the API Keys page to cut off access.
- Scopes:

| Scope | Allows |
|---|---|
| `read` | All `GET` endpoints and the streams |
| `trade` | Also: place, modify and cancel orders, protect, close, flatten, create/evaluate strategies |

Every valid key can call the read endpoints. Endpoints that change anything need the `trade` scope; without it they answer `403 MISSING_SCOPE`. Give a key `trade` only if it must trade.

Each key only sees the accounts of the user who created it. An account id that is not yours answers `404 ACCOUNT_NOT_FOUND`.

## Plan

Endpoints that place, modify or cancel orders, protect, close or flatten, and the strategy write endpoints, need an active **Pro** subscription ($29/month flat) or free trial. Otherwise they answer `403 PLAN_REQUIRED`. Read endpoints do not check the plan.

## Rate limits

| Limit | Applies to | Over the limit |
|---|---|---|
| **120 requests per minute** per API key | Every `/api/v1` request | `429 {"error": "Rate limit exceeded"}` |
| **12 reads per minute of the same path** per API key (one every 5 seconds) | `GET` requests, except the streams | `429 {"error": "Polling too fast: at most 12 reads per minute of the same endpoint"}` |
| **5 open streams** per user | `GET /stream` | `429 TOO_MANY_STREAMS` |

- "The same path" includes the account id: `/accounts/A/positions` and `/accounts/B/positions` are counted separately. Query strings are not part of the path.
- Responses carry the standard `RateLimit-*` headers.
- Writes (`POST`, `PUT`, `DELETE`) only count toward the 120/minute limit.
- For anything live, use [`GET /stream`](streaming.md) instead of polling.

Note that the `429` bodies of the two per-minute limits are `{"error": "..."}` with a plain string, not the usual error object.

## Idempotency

`POST /accounts/{id}/orders` accepts an `Idempotency-Key` header (8 to 128 characters). Use a new unique value for each order you mean to place, and the same value when you retry that order.

```bash
curl -X POST https://signaltradeapp.com/api/v1/accounts/ACCOUNT_ID/orders \
  -H "X-API-Key: $STA_API_KEY" \
  -H "Idempotency-Key: entry-2026-11-17-001" \
  -H "Content-Type: application/json" \
  -d '{"symbol":"MNQ","action":"Buy","qty":1}'
```

- The response is stored for **24 hours**. A retry with the same key gets the stored response and places nothing.
- Refusals are stored too (`422`, `409 BRACKET_INCOMPLETE`, `502`), so a retry never turns a refusal into a second live order.
- Keys are scoped to your user. A key outside 8 to 128 characters answers `400 INVALID_IDEMPOTENCY_KEY`.
- Only this endpoint supports idempotency.

## Errors

Errors use one shape:

```json
{
  "error": {
    "message": "Validation failed",
    "code": "VALIDATION_ERROR",
    "details": [
      { "field": "price", "message": "price is required for Limit and Stop orders" }
    ]
  }
}
```

`details` is present for validation errors only. When an error has no specific code, `code` is `HTTP_<status>` (for example `HTTP_503`).

| Status | Code | Meaning | Retry? |
|---|---|---|---|
| 400 | `VALIDATION_ERROR` | A body, path or query field is wrong. See `details` | No, fix the request |
| 400 | `UNKNOWN_SYMBOL` | The symbol could not be mapped to a contract. Nothing was sent | No |
| 400 | `INVALID_BRACKET` | TP/SL on the wrong side of the entry or market | No |
| 400 | `INVALID_IDEMPOTENCY_KEY` | `Idempotency-Key` not 8 to 128 characters | No |
| 400 | (none) | The broker rejected a modify; the message carries its reason | No |
| 401 | `MISSING_API_KEY` / `INVALID_API_KEY` | No key, or a revoked/unknown key | No |
| 403 | `MISSING_SCOPE` | The key lacks the `trade` scope | No |
| 403 | `PLAN_REQUIRED` | No active Pro subscription or trial | No |
| 403 | `ACCOUNT_LOCKED` | The account is locked (Risk page lockout or daily P&L lock). New orders are refused; flatten and close still work | After the lock ends |
| 403 | `ACCOUNT_INACTIVE` | The broker no longer reports the account (ended evaluation, removed) | No |
| 403 | `MARKET_DATA_DISABLED` | Quote and candle endpoints are disabled | No |
| 404 | `ACCOUNT_NOT_FOUND` | Unknown account, or not yours | No |
| 409 | `CANCEL_REJECTED` | The broker refused the cancel, usually because the order already filled | No, terminal |
| 409 | `BRACKET_INCOMPLETE` | The entry was placed but the broker refused a TP/SL leg. The position may be unprotected | No. Inspect the account |
| 409 | `POSITION_CHANGED` | `expected` did not match the live position. Nothing was sent | Re-read, then decide |
| 409 | `POSITION_AMBIGUOUS` | Two months of the symbol are held. Name the contract | With the contract |
| 409 | `PROTECTION_CANCEL_FAILED` | Old protection could not be cancelled; nothing new placed; the original is still working | Yes |
| 409 | `MODIFY_REPLACE_REJECTED` | Rithmic: the order was cancelled for a re-place and the replacement was rejected. It is no longer working | No. Place fresh protection |
| 409 | (none) | Another protection update is in progress for this symbol | Yes, shortly |
| 422 | `BROKER_ORDER_REJECTED` | The broker refused the order; the message carries its reason | No, terminal |
| 429 | `TOO_MANY_STREAMS` / rate limit | See [Rate limits](#rate-limits) | After a pause |
| 500 | `INTERNAL_ERROR` | Unexpected error | Contact support |
| 501 | `NOT_SUPPORTED` | This broker connection cannot do that operation | No |
| 502 | `BROKER_ORDER_REJECTED` | The broker returned no order id. The order **may or may not** be working | Check `working-orders` first |
| 503 | `BROKER_NOT_CONNECTED` / `BROKER_UNAVAILABLE` | Our connection to the broker is down for a moment | Yes |
| 503 | `BROKER_LOGIN_REFUSED` | The broker refuses this connection's login. The message carries its reason | Not until the login is fixed |
| 503 | `POSITIONS_UNKNOWN` | Positions have not loaded yet (just after a reconnect). Nothing was sent | Yes, in a few seconds |
| 503 | `HTTP_503` | Order entry paused for scheduled maintenance. Cancels, modifies and closes still work | Later |

## Symbols

| You send | Meaning |
|---|---|
| `MNQZ6`, `MNQZ26`, `MNQZ2026` | That exact contract |
| `MNQ`, `MNQ1!`, `MNQ!`, `CME_MINI:MNQ1!`, `MNQ=F`, `/MNQ` | The current front month |
| `/MNQZ26:XCME`, `MNQ 12-26` | Platform spellings of one contract |

`MNQ2!` and deeper continuous months are refused. Unresolvable symbols answer `400 UNKNOWN_SYMBOL` and nothing is sent.

## Order ids

Order ids are the broker's own. Treat them as opaque strings.

- **Tradovate** modifies in place. A plain resting order keeps its id. A **bracket leg** (the stop or take-profit of a bracket) does not: after the **first** modify, Tradovate re-issues both legs under **new ids** at the same prices. Later modifies keep the id. The broker OCO link survives.
- **Rithmic** has no in-place modify. A modify is a cancel plus a re-place and returns `replaced: true`; the order now has a new id.
- Cancelling **one** leg of a filled bracket re-places the surviving leg under a new id.
- `POST /protect` always places new orders, so every leg id changes on every call.

**Rule: re-read `GET /accounts/{id}/working-orders` before each modify or cancel. Never cache order ids.**

---

## Accounts

### GET /accounts

Lists your connected accounts.

```bash
curl -H "X-API-Key: $STA_API_KEY" https://signaltradeapp.com/api/v1/accounts
```

```json
{
  "data": [
    {
      "id": "ACCOUNT_ID",
      "name": "MFFU50K-12345",
      "broker": "TRADOVATE",
      "environment": "DEMO",
      "status": "ACTIVE",
      "balance": 50349.44,
      "brokerId": "1234567",
      "dayPnl": 349.44,
      "tradingDay": "2026-11-17"
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `id` | Our account id. Every other endpoint uses this |
| `brokerId` | The broker's own account id |
| `status` | `ACTIVE`, `LOCKED`, `INACTIVE` or `SUSPENDED` |
| `dayPnl` | Today's realized P&L, **net of commissions** (the app's Day P&L). Open P&L is not included |
| `tradingDay` | The CME trading day `dayPnl` belongs to. It rolls at 17:00 New York time; Tradovate accounts use the broker's own trade date |

## Positions

### GET /accounts/{id}/positions

Open positions on one account.

```bash
curl -H "X-API-Key: $STA_API_KEY" https://signaltradeapp.com/api/v1/accounts/ACCOUNT_ID/positions
```

```json
{
  "data": [
    {
      "id": "…",
      "accountId": "ACCOUNT_ID",
      "symbol": "MNQZ6",
      "side": "LONG",
      "qty": 2,
      "avgPrice": 21020.0,
      "openPnl": 0,
      "openedAt": "2026-11-17T14:30:00.000Z",
      "updatedAt": "2026-11-17T14:30:01.000Z"
    }
  ]
}
```

`avgPrice` is the broker's average entry. `openPnl` here is a stored value and may lag or read 0; for live open P&L use the `position` events on [`GET /stream`](streaming.md).

### POST /accounts/{id}/positions/close

Closes **one symbol** with a broker-sized close, then cancels that symbol's working orders. Other symbols are untouched. Needs `trade`.

| Body field | Type | Required | Notes |
|---|---|---|---|
| `symbol` | string | yes | Root (`MNQ`, `MNQ1!`) or contract (`MNQZ6`) |
| `expected` | object | no | `{ "side": "LONG"\|"SHORT", "qty": number, "avgPrice": number }`. Only close if the live position is still this one |

```bash
curl -X POST https://signaltradeapp.com/api/v1/accounts/ACCOUNT_ID/positions/close \
  -H "X-API-Key: $STA_API_KEY" -H "Content-Type: application/json" \
  -d '{"symbol":"MNQ","expected":{"side":"LONG","qty":2,"avgPrice":21020.0}}'
```

```json
{ "data": { "symbol": "MNQ", "closed": ["MNQZ6"], "cancelledOrders": 2 } }
```

- `expected` protects a delayed or retried close. If the position already exited, or a new one opened, you get `409 POSITION_CHANGED` and nothing is closed or cancelled. Include `avgPrice`: it is what tells your position apart from a new one of the same side and size.
- With `expected`, two months of one root held answers `409 POSITION_AMBIGUOUS`. Name the contract.
- Without `expected`, a `200` with an empty `closed` list means nothing was held.
- `503 POSITIONS_UNKNOWN`: positions have not loaded yet. Nothing was sent. Retry.

### DELETE /accounts/{id}/positions

Flattens the **whole account**: closes every position and cancels resting orders. Needs `trade`. Works on a locked account.

```bash
curl -X DELETE -H "X-API-Key: $STA_API_KEY" \
  https://signaltradeapp.com/api/v1/accounts/ACCOUNT_ID/positions
```

```json
{ "data": { "success": true } }
```

## Orders

### POST /accounts/{id}/orders

Places an order. Needs `trade`. Supports [`Idempotency-Key`](#idempotency).

| Body field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `symbol` | string | yes | | See [Symbols](#symbols) |
| `action` | `"Buy"` \| `"Sell"` | yes | | Lowercase also accepted |
| `qty` | integer | yes | | Whole contracts. A decimal is refused with `400` |
| `orderType` | `"Market"` \| `"Limit"` \| `"Stop"` | no | `"Market"` | Case-insensitive |
| `price` | number | for Limit/Stop | | Limit price or stop trigger |
| `takeProfit` | number | no | | Absolute TP price. Same as `bracket.takeProfit` |
| `stopLoss` | number | no | | Absolute SL price. Same as `bracket.stopLoss` |
| `bracket` | object | no | | `{ "takeProfit": number, "stopLoss": number }`. Wins over the top-level fields |
| `timeInForce` | `"Day"` \| `"GTC"` | no | `"Day"` | How long the bracket legs (and a Limit/Stop entry) rest |

**Brackets.** TP and SL are linked one-cancels-other at the broker. They must be on the correct side: for a Buy, TP above and SL below the entry price (Limit/Stop) or the market (Market); otherwise `400 INVALID_BRACKET`.

**timeInForce.** `Day` legs expire at the session close, so a position held overnight loses its protection. `GTC` rests until filled or cancelled. If your account refuses GTC (some prop firms do), the order is rejected with the broker's reason. It is never quietly downgraded to Day.

```bash
curl -X POST https://signaltradeapp.com/api/v1/accounts/ACCOUNT_ID/orders \
  -H "X-API-Key: $STA_API_KEY" -H "Content-Type: application/json" \
  -H "Idempotency-Key: $(uuidgen)" \
  -d '{"symbol":"MNQ","action":"Buy","qty":1,"orderType":"Limit","price":21000,
       "takeProfit":21050,"stopLoss":20970,"timeInForce":"GTC"}'
```

`201`:

```json
{ "data": { "orderId": "616507970052" } }
```

With a bracket, the answer waits briefly for the broker to accept each leg:

| Outcome | Answer |
|---|---|
| All accepted | `201` |
| A leg not confirmed in time | `201` with `"warnings": ["stopLoss at 20970 was not confirmed by the broker in time — verify it is working"]` |
| Entry refused | `422 BROKER_ORDER_REJECTED`, `details.orderId`. Nothing is on the account |
| Entry placed, a leg refused | `409 BRACKET_INCOMPLETE`, `details: { orderId, accepted, rejected }`. The position may be unprotected. Inspect the order; do not resubmit |

Other refusals: `403 ACCOUNT_LOCKED`, `403 ACCOUNT_INACTIVE`, `422 BROKER_ORDER_REJECTED` (with the broker's reason), `502` (no order id: check `working-orders` before retrying), `503 BROKER_NOT_CONNECTED`.

### GET /accounts/{id}/orders

**Trade history**, not live orders. (The name is kept for backwards compatibility.) For orders resting at the broker, use [`/working-orders`](#get-accountsidworking-orders).

| Query | Type | Default | Notes |
|---|---|---|---|
| `limit` | integer | 100 | 1 to 500 |
| `symbol` | string | | Case-insensitive exact match, e.g. `MNQZ6` |
| `side` | `LONG` \| `SHORT` | | |
| `since` | ISO date-time | | Trades opened at or after |
| `cursor` | string | | `meta.nextCursor` from the previous page |

Newest first.

```bash
curl -H "X-API-Key: $STA_API_KEY" \
  "https://signaltradeapp.com/api/v1/accounts/ACCOUNT_ID/orders?limit=50&since=2026-11-17T00:00:00Z"
```

```json
{
  "data": [
    {
      "id": "TRADE_ID",
      "accountId": "ACCOUNT_ID",
      "symbol": "MNQZ6",
      "side": "LONG",
      "qty": 2,
      "entryPrice": 21020.0,
      "exitPrice": 21045.0,
      "pnl": 100.0,
      "gross": 100.0,
      "fees": 3.04,
      "net": 96.96,
      "openedAt": "2026-11-17T14:30:00.000Z",
      "closedAt": "2026-11-17T14:41:12.000Z"
    }
  ],
  "meta": { "limit": 50, "nextCursor": "TRADE_ID" }
}
```

- `pnl` and `gross` are **gross** (price difference × quantity × point value). `fees` is the broker commission for the trade (entry + exit, or entry only while open). `net` = `gross` − `fees`.
- Sum `net` by trading day to match the app's Day P&L and calendar.
- `nextCursor` is present only when the page is full.

### GET /accounts/{id}/working-orders

Orders resting on the broker's book now: unfilled entries and active TP/SL legs. Read live from the broker. Poll this to decide whether an order still needs cancelling, and re-read it before every modify.

```bash
curl -H "X-API-Key: $STA_API_KEY" \
  https://signaltradeapp.com/api/v1/accounts/ACCOUNT_ID/working-orders
```

```json
{
  "data": [
    {
      "id": 616507970311,
      "accountId": 1234567,
      "symbol": "MNQZ6",
      "action": "Sell",
      "orderType": "Stop",
      "stopPrice": 21010.25,
      "orderQty": 2,
      "ordStatus": "Working",
      "timeInForce": "Day",
      "ocoGroupId": "…"
    }
  ]
}
```

The fields are the broker's order as we hold it, so names differ a little between brokers. Read defensively:

| What | Look in |
|---|---|
| Id | `id` |
| Side | `action` (or `side`): `Buy` / `Sell` |
| Type | `orderType` or `ordType`: `Limit`, `Stop`, … |
| Price | `price`; a Tradovate stop carries its trigger in `stopPrice` |
| Quantity | `orderQty` (or `qty`) |
| `accountId` | The **broker's** account id (`brokerId` from `/accounts`), not ours |

A stop protecting a long is a `Sell` stop; a stop protecting a short is a `Buy` stop.

### PUT /accounts/{id}/orders/{orderId}

Moves one resting order to a new price, and optionally a new size, **without cancelling it first**. This is how you move a stop to breakeven or trail it. Needs `trade`.

| Body field | Type | Required | Notes |
|---|---|---|---|
| `price` | number | yes | New price. For a stop, the trigger price |
| `qty` | integer | no | Omit to keep the current size. A reprice never resizes on its own |
| `orderType` | `"Limit"` \| `"Stop"` | no | Ignored when the broker knows the order's type. A reprice can never turn a Stop into a Limit |

```bash
curl -X PUT https://signaltradeapp.com/api/v1/accounts/ACCOUNT_ID/orders/616507970311 \
  -H "X-API-Key: $STA_API_KEY" -H "Content-Type: application/json" \
  -d '{"price": 21020.0}'
```

```json
{ "data": { "success": true } }
```

- **Tradovate:** repriced in place; the stop never leaves the book. No `replaced` field. A **bracket leg** gets a **new id** about a second after its **first** modify (both legs are re-issued at the same prices, OCO intact). Later moves keep the id.
- **Rithmic:** `"replaced": true`. The order was cancelled and re-placed under a new id, with a brief moment with nothing resting. If the broker then rejects the replacement, you get `409 MODIFY_REPLACE_REJECTED`: that order is gone and the position may be unprotected.
- If the order is a leg of protection placed with `POST /protect`, the move re-applies that protection: the response has `"replaced": true`, `ocoGroupId` and `legs`.
- `"filled": true` means the moved order filled straight away.
- The response does **not** give you the new id. Re-read `working-orders`.
- Broker rejections (for example a stop through the market) answer `400` with the broker's reason. The order stays where it was (Tradovate).

### DELETE /accounts/{id}/orders/{orderId}

Cancels one order. Needs `trade`. **Never closes a position**, even if you cancel the last stop.

```bash
curl -X DELETE -H "X-API-Key: $STA_API_KEY" \
  https://signaltradeapp.com/api/v1/accounts/ACCOUNT_ID/orders/616507970052
```

```json
{ "data": { "orderId": "616507970052", "cancelled": true } }
```

- **Unfilled bracket entry:** cancelling the entry also removes its TP/SL. Cancel the entry id only.
- **Filled bracket:** the legs are live protection; cancel them by their own ids. Cancelling one leg re-places the other under a new id.
- **Partially filled entry:** the filled part stays open; only the rest is cancelled.
- **Racing a fill:** `409 CANCEL_REJECTED` with the broker's reason. Terminal: stop retrying. `503` is retryable. Cancelling an already-cancelled order returns `200`.

## Protection

### POST /accounts/{id}/protect

Attaches or **replaces** broker-native TP/SL protection (an OCO pair) on an open position. Needs `trade`.

| Body field | Type | Required | Notes |
|---|---|---|---|
| `symbol` | string | yes | The position's symbol |
| `takeProfit` | number \| `null` | one of the two | Omit = keep the current TP. `null` = remove it |
| `stopLoss` | number \| `null` | one of the two | Omit = keep the current SL. `null` = remove it |
| `qty` | integer | no | Defaults to the full position |
| `timeInForce` | `"Day"` \| `"GTC"` | no | Applies to both legs. Omitted: keep what the live protection has; with none live, `Day` |
| `expected` | object | no | `{ side, qty, avgPrice }`, as for `positions/close` |

```bash
curl -X POST https://signaltradeapp.com/api/v1/accounts/ACCOUNT_ID/protect \
  -H "X-API-Key: $STA_API_KEY" -H "Content-Type: application/json" \
  -d '{"symbol":"MNQ","takeProfit":21100,"stopLoss":20980,"timeInForce":"GTC"}'
```

`201`:

```json
{
  "data": {
    "ocoGroupId": "…",
    "legs": [
      { "kind": "TP", "orderId": "616507970400" },
      { "kind": "SL", "orderId": "616507970401" }
    ]
  }
}
```

- **Replacement is total.** Everything protecting the position before is cancelled first, including legs the broker attached to an entry bracket. `201` means nothing stale is still working.
- If the old protection cannot be cancelled: `409 PROTECTION_CANCEL_FAILED`. Nothing new was placed; the original is still live.
- **Omitting a leg keeps it** at its current live level. Sending both as `null` is refused.
- TP must be above SL for a long and below for a short.
- `legs[].orderId` are real order ids you can `PUT` or `DELETE`. `ocoGroupId` is a grouping token, **not** an order id.
- Every call places new orders, so every leg id changes. Re-read them.
- To move just the stop, prefer `PUT /accounts/{id}/orders/{orderId}` on the stop. On Tradovate that leaves no unprotected moment.
- `409` "another protection update is in progress": retry shortly.

## Risk

### GET /accounts/{id}/risk

Risk settings, lock state and remaining drawdown.

```bash
curl -H "X-API-Key: $STA_API_KEY" https://signaltradeapp.com/api/v1/accounts/ACCOUNT_ID/risk
```

```json
{
  "data": {
    "accountId": "ACCOUNT_ID",
    "broker": "TRADOVATE",
    "dailyLossLimit": 1000,
    "dailyProfitTarget": null,
    "weeklyLossLimit": null,
    "weeklyProfitTrigger": null,
    "maxOpeningOrderQty": 5,
    "trailingMaxDrawdown": null,
    "lockedUntil": null,
    "brokerRms": null,
    "drawdown": {
      "equity": 50153.5,
      "balance": 50112.5,
      "drawdownLimit": 2000,
      "drawdownType": "TRAILING",
      "peakBalance": 50300,
      "liquidationLevel": 48300,
      "drawdownRemaining": 1853.5,
      "source": "broker",
      "profitTarget": 3000,
      "targetBalance": 53000,
      "profitToPass": 2846.5,
      "updatedAt": "2026-11-17T19:12:06.000Z"
    }
  }
}
```

| Field | Meaning |
|---|---|
| `lockedUntil` | When set and in the future, the account is locked and refuses new orders |
| `drawdown.equity` | Balance plus open P&L |
| `drawdown.liquidationLevel` | The equity at which the account is liquidated |
| `drawdown.drawdownRemaining` | `equity − liquidationLevel`. Negative means the line was crossed |
| `drawdown.drawdownType` | `STATIC`, `TRAILING`, `EOD_TRAILING`, or `null` when unknown |
| `drawdown.source` | `broker` when the broker reports the rule, `configured` when it comes from what you entered on the Risk page, `null` when neither is known (then all values are `null`) |
| `drawdown.profitToPass` | `targetBalance − equity`. Zero or less means the target is reached. `null` without a profit target |
| `brokerRms` | Rithmic's raw risk block, read-only. Its `autoLiqThresholdCurrentValue` is a balance level, not headroom |

The live version of `drawdown` is the `risk` event on the stream.

## Fills and P&L

### GET /fills

Every execution on your accounts, as the broker reported it, **oldest first**.

| Query | Type | Default | Notes |
|---|---|---|---|
| `accountId` | string | | One account only |
| `after` | string | | A `cursor` from a previous response: fills after it |
| `since` | ISO date-time | | Executed at or after |
| `limit` | integer | 500 | 1 to 1000 |

```bash
curl -H "X-API-Key: $STA_API_KEY" "https://signaltradeapp.com/api/v1/fills?after=1042&limit=500"
```

```json
{
  "data": [
    {
      "id": "616507970099",
      "cursor": "1043",
      "accountId": "ACCOUNT_ID",
      "accountName": "MFFU50K-12345",
      "brokerAccountId": "1234567",
      "orderId": "616507970052",
      "brokerFillId": "616507970099",
      "symbol": "MNQZ6",
      "side": "LONG",
      "action": "BUY",
      "qty": 1,
      "price": 21020.0,
      "fees": 0.52,
      "timestamp": "2026-11-17T14:30:00.512Z"
    }
  ],
  "meta": { "limit": 500, "nextCursor": "1043", "hasMore": false }
}
```

- `id` is stable and unique per account. Deduplicate by `accountId` + `id`.
- `side` `LONG` = a buy, `SHORT` = a sell (`action` says the same as `BUY`/`SELL`). `price` is this execution's own price, not the order average.
- `fees` and `brokerFillId` are read from the broker's records. On Tradovate they appear within about 15 seconds; until then they are `null`.
- Each fill also arrives live as a `fill` event on the stream with the same `id`. Keep the last `cursor` you processed and call `/fills?after=<cursor>` after a reconnect to catch up.
- Fills made while our broker connection was down are recovered from the broker's history when it reconnects (Tradovate: same trading day).
- The ledger starts recording when your first API key exists.

### GET /pnl/daily

Realized P&L per futures trading day (6 PM to 5 PM New York time), in total and per account.

| Query | Type | Notes |
|---|---|---|
| `accountId` | string | Optional |
| `from` | `YYYY-MM-DD` | Default: 30 days before `to` |
| `to` | `YYYY-MM-DD` | Default: the current trading day |

At most 366 days per request; `from` must not be after `to`.

```bash
curl -H "X-API-Key: $STA_API_KEY" "https://signaltradeapp.com/api/v1/pnl/daily?from=2026-11-01&to=2026-11-17"
```

```json
{
  "data": {
    "from": "2026-11-01",
    "to": "2026-11-17",
    "total": 1240.5,
    "days": [ { "date": "2026-11-03", "pnl": 410.0 } ],
    "rows": [ { "accountId": "ACCOUNT_ID", "accountName": "MFFU50K-12345", "date": "2026-11-03", "pnl": 410.0 } ]
  }
}
```

## Groups, connections, copies, user

### GET /groups

Your copy groups (read-only; change them on the website).

```json
{
  "data": [
    {
      "id": "GROUP_ID",
      "name": "Main",
      "isDefault": true,
      "leader": { "accountId": "ACCOUNT_ID", "accountName": "…", "broker": "TRADOVATE", "accountStatus": "ACTIVE" },
      "followers": [
        {
          "accountId": "FOLLOWER_ID",
          "accountName": "…",
          "broker": "RITHMIC",
          "accountStatus": "ACTIVE",
          "copyRatio": 1,
          "following": true,
          "inverseCopy": false,
          "copyDelaySeconds": 0,
          "symbolRules": null
        }
      ]
    }
  ]
}
```

`following: false` means the follower is paused.

### GET /connections

Every broker connection and its status: `CONNECTED`, `RECONNECTING`, `AUTH_EXPIRED`, `ERROR`, `DISCONNECTED` or `DISABLED`.

```json
{
  "data": [
    {
      "id": "CONNECTION_ID",
      "name": "My Tradovate",
      "broker": "TRADOVATE",
      "environment": "DEMO",
      "status": "CONNECTED",
      "errorMessage": null,
      "lastSyncAt": "2026-11-17T14:00:00.000Z",
      "accountCount": 3
    }
  ]
}
```

The live version is [`GET /connection-health/stream`](streaming.md#get-connection-healthstream).

### GET /copies

The last copy attempts (at most 10, within 24 hours, newest first). This list is kept in memory and is emptied when the server restarts.

```json
{
  "data": [
    {
      "id": "…",
      "leaderAccountName": "…",
      "followerAccountName": "…",
      "symbol": "MNQZ6",
      "side": "LONG",
      "qty": 1,
      "orderType": "Market",
      "latencyMs": 48,
      "leaderFillAt": 1763389800000,
      "copiedAt": 1763389800048,
      "status": "success"
    }
  ],
  "meta": { "summary": { "avgMs": 48, "maxMs": 48, "count": 1 }, "window": "last 10 attempts within 24h; reset on restart" }
}
```

### GET /user

```json
{
  "data": {
    "id": "USER_ID",
    "email": "you@example.com",
    "firstName": "…",
    "lastName": "…",
    "plan": "PRO",
    "role": "USER",
    "timezone": "America/New_York",
    "createdAt": "2026-01-01T00:00:00.000Z"
  }
}
```

## Streams

| Endpoint | What |
|---|---|
| `GET /stream` | Orders, fills, positions, balances, drawdown, locks, connection status |
| `GET /connection-health/stream` | Broker connection status only |

Both are Server-Sent Events. See [streaming.md](streaming.md).

## Market data

`GET /market/quotes/{symbol}` and `GET /market/candles` always answer `403 MARKET_DATA_DISABLED`. The API has no prices.

## Strategies (beta)

Simple stored rules. They **do not trade on their own**.

| Method | Path | Scope | Notes |
|---|---|---|---|
| GET | `/strategies` | read | Your strategies |
| POST | `/strategies` | trade | Create one |
| POST | `/strategies/{id}/evaluate` | trade | Check the rule now. Returns `{ strategyId, detail, currentValue, triggered }` |
| GET | `/strategies/{id}/logs` | read | Last 100 execution log rows |

Create body:

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | Up to 128 characters |
| `description` | string | no | Up to 1024 characters |
| `symbol` | string | yes | |
| `conditions` | object | yes | `{ "indicator": "price" \| "sma" \| "rsi", "operator": "gt" \| "lt", "value": number, "period": integer }`. `period` defaults to 20 for `sma`, 14 for `rsi` |
| `action` | `"buy"` \| `"sell"` \| `"flatten"` | yes | |
| `qty` | integer | no | Default 1 |
| `orderType` | `"market"` \| `"limit"` \| `"stop"` | no | Default `"market"` |
| `targetAccountId` | string | no | |

`evaluate` needs a price for the symbol; when none is available it answers `400`.
