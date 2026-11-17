# Recipes

Worked examples that combine [webhooks](tradingview-webhooks.md), the [REST API](rest-api.md) and the [stream](streaming.md). Test each one on a demo or evaluation account first.

- [Staged stop: breakeven at +$X, then lock $Y at +$Z](#staged-stop)
- [Cancel an unfilled limit after N bars](#cancel-an-unfilled-limit-after-n-bars)
- [Flatten at the end of the session](#flatten-at-the-end-of-the-session)
- [Scale out with protect](#scale-out-with-protect)
- [Read fills for a journal](#read-fills-for-a-journal)
- [Close only if it is still my position](#close-only-if-it-is-still-my-position)

---

## Staged stop

Goal, on a long of 2 NQ entered at 21,000 with a stop at 20,970:

1. When open profit reaches **+$1,300**, move the stop to **breakeven**.
2. When open profit reaches **+$2,540**, move the stop to lock in **$1,740**.

The math, for reference: NQ is $20 a point, so 2 contracts move $40 per point. $1,740 / $40 = 43.5 points, so step 2 puts the stop at 21,043.50.

### With webhooks

Send two `movestop` alerts. You never compute the price: the server reads the broker's average entry and the position size, and rounds to the tick.

Step 1, at +$1,300:

```json
{"action": "movestop", "symbol": "NQ1!", "offsetPoints": 0}
```

Step 2, at +$2,540:

```json
{"action": "movestop", "symbol": "NQ1!", "lockUsd": 1740}
```

- The stop is **moved, not replaced**. The take-profit stays where it is, and on Tradovate it stays OCO-linked at the broker.
- If the market has already come back through the new level, the alert is refused and the stop is left where it was ("…Your stop was left at 20970.").
- The position must have **exactly one** working stop. A stop split by `protect` into several legs is refused with `409`.
- Prefer `movestop` with `offsetPoints: 0` over `breakeven` for this: `breakeven` cancels the old stop before placing the new one, so there is a brief moment with no stop.

[`examples/pine/staged_stop.pine`](../../examples/pine/staged_stop.pine) is a strategy that sends both alerts from `strategy.openprofit`. [`examples/curl/webhook_movestop.sh`](../../examples/curl/webhook_movestop.sh) sends one by hand.

### With the REST API

Over REST you compute the price yourself and reprice the stop with `PUT /accounts/{id}/orders/{orderId}`.

Before **every** move:

1. `GET /accounts/{id}/positions` → the position's `side`, `qty` and `avgPrice` (the broker average entry).
2. `GET /accounts/{id}/working-orders` → find the **one** stop protecting it: same contract, type `Stop`, on the closing side (`Sell` for a long, `Buy` for a short). If there is none or more than one, stop and ask a human.
3. Compute the price: `avgPrice ± lockUsd / (pointValue × qty)`, toward profit. Round to the tick **away from the market** (down for a long, up for a short).
4. `PUT /accounts/{id}/orders/{stopId}` with `{"price": newPrice}`.

```bash
# 1 + 2: read the position and the stop
curl -s -H "X-API-Key: $STA_API_KEY" "$BASE/accounts/$ACCOUNT_ID/positions"
curl -s -H "X-API-Key: $STA_API_KEY" "$BASE/accounts/$ACCOUNT_ID/working-orders"
# 4: move stop 616507970311 to breakeven
curl -s -X PUT -H "X-API-Key: $STA_API_KEY" -H "Content-Type: application/json" \
  -d '{"price": 21000.00}' "$BASE/accounts/$ACCOUNT_ID/orders/616507970311"
```

Why re-read the ids every time:

- **Tradovate:** after the **first** modify of a bracket leg, the stop and the take-profit are re-issued under **new order ids** at the same prices. A second `PUT` to the old id fails. Later moves keep the id.
- **Rithmic:** every modify is a cancel plus a re-place, so the stop comes back under a new id (`"replaced": true`).
- The `PUT` response does not contain the new id.

So: never cache an order id between moves. Wait a second or two after a move, then re-read `working-orders`.

To know **when** to move, watch open P&L on the stream (`position` events carry `openPnl`), not by polling. The API has no market data.

[`examples/python/staged_stop.py`](../../examples/python/staged_stop.py) does all of this with the Python standard library.

> **Managed protection ON:** Signal Trade App manages the stop and target itself. It detaches the stop from the broker OCO and cancels the take-profit when the stop fills.

---

## Cancel an unfilled limit after N bars

### With webhooks

1. Entry alert, a limit with its bracket:

   ```json
   {"action": "buy", "symbol": "MNQ1!", "qty": 1, "orderType": "limit", "price": 21000.00, "takeProfit": 21040.00, "stopLoss": 20980.00}
   ```

2. N bars later, if your script thinks it has not filled, send:

   ```json
   {"action": "cancel", "symbol": "MNQ1!"}
   ```

`cancel` only removes **unfilled entry** orders (their TP/SL go with them). If the limit did fill in the meantime, its stop and target are kept and the position stays open, so a late `cancel` is safe: it finds no entry to cancel.

[`examples/pine/cancel_unfilled_limit.pine`](../../examples/pine/cancel_unfilled_limit.pine) does this with a bar counter.

### With the REST API

1. `POST /accounts/{id}/orders` with `"orderType": "Limit"`. Keep the `orderId` from the answer.
2. After your timeout, `GET /accounts/{id}/working-orders`. If the id is still there, `DELETE /accounts/{id}/orders/{orderId}`.
3. If the cancel races a fill you get `409 CANCEL_REJECTED`. That is final: the order filled. Do not retry. `503` is safe to retry.

See [`examples/curl/place_limit_then_cancel.sh`](../../examples/curl/place_limit_then_cancel.sh).

---

## Flatten at the end of the session

### With webhooks

At your cut-off time, send one of:

```json
{"action": "close", "symbol": "MNQ1!"}
```

```json
{"action": "close"}
```

The first closes MNQ and cancels MNQ's working orders, leaving other symbols alone. The second flattens the whole account.

[`examples/pine/session_flatten.pine`](../../examples/pine/session_flatten.pine) fires at a fixed New York time.

### With the REST API

From a scheduler (cron, a cloud function) at your cut-off time:

```bash
# one symbol
curl -X POST -H "X-API-Key: $STA_API_KEY" -H "Content-Type: application/json" \
  -d '{"symbol":"MNQ"}' "$BASE/accounts/$ACCOUNT_ID/positions/close"

# the whole account
curl -X DELETE -H "X-API-Key: $STA_API_KEY" "$BASE/accounts/$ACCOUNT_ID/positions"
```

Both work on a locked account and while order entry is paused for maintenance. On `503`, retry: nothing was sent.

---

## Scale out with protect

Two alerts. The entry, then once it has filled, the exit plan. **Managed protection must be on** (Settings → Trading, switched while flat).

1. Entry (no bracket):

   ```json
   {"action": "buy", "symbol": "MNQ1!", "qty": 4}
   ```

2. Exit plan:

   ```json
   {"action": "protect", "symbol": "MNQ1!", "sl": [20960], "tp": [21040, 21080], "beAfterTp1": true, "beOffsetTicks": 1}
   ```

Result: two targets of 2 contracts each, one stop for all 4. When the first target fills, the stop shrinks to 2 and moves to the entry price plus 1 tick.

Variations:

```json
{"action": "protect", "symbol": "MNQ1!", "sl": 20960, "tp": [21030, 21050, 21070], "autoBreakevenUsd": 200}
```

Three targets, and the stop goes to breakeven once the trade is $200 in profit.

A **manual** scale-out with partial closes, which keeps your stop and target sized to what is left:

```json
{"action": "close", "symbol": "MNQ1!", "percent": 50}
```

[`examples/pine/scale_out_protect.pine`](../../examples/pine/scale_out_protect.pine) sends the protect alert on the bar after the entry fills.

> REST note: `POST /accounts/{id}/protect` sets one TP and one SL. For several targets use the webhook `protect` action.

---

## Read fills for a journal

`GET /fills` is a ledger of every execution, oldest first, with a cursor. A journal sync is:

1. Load the last `cursor` you saved (none on the first run).
2. `GET /fills?after=<cursor>&limit=1000`. Store each row keyed by `accountId` + `id` (insert or update: `fees` and `brokerFillId` can arrive up to about 15 seconds later on Tradovate, so a row can be re-read with them filled in).
3. Save `meta.nextCursor`. If `meta.hasMore` is `true`, repeat step 2 right away.
4. Run again on a schedule, or keep a [stream](streaming.md) open for live `fill` events and use step 2 to catch up after each reconnect.

```bash
curl -s -H "X-API-Key: $STA_API_KEY" "$BASE/fills?after=$CURSOR&limit=1000"
```

For round-trip trades with P&L instead of single fills, use `GET /accounts/{id}/orders` (trade history): `gross`, `fees`, `net` per trade. For one number per day, `GET /pnl/daily`. Sum `net` by trading day to match the app.

The fill ledger starts recording when your first API key exists. Earlier fills are not in it.

See [`examples/curl/fills_since_cursor.sh`](../../examples/curl/fills_since_cursor.sh).

---

## Close only if it is still my position

A close or protect request that is delayed or retried can land after your position has already exited and a new one opened. Send `expected` with what you last saw on the stream:

```bash
curl -X POST -H "X-API-Key: $STA_API_KEY" -H "Content-Type: application/json" \
  -d '{"symbol":"MNQ","expected":{"side":"LONG","qty":2,"avgPrice":21020.0}}' \
  "$BASE/accounts/$ACCOUNT_ID/positions/close"
```

If the live position differs, you get `409 POSITION_CHANGED` and nothing is sent. Include `avgPrice`: it tells your position apart from a new one of the same side and size. The same `expected` field works on `POST /accounts/{id}/protect`.
