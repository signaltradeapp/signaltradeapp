# TradingView webhooks

A webhook lets a TradingView alert, or any program that can send an HTTP POST, trade one of your accounts. If that account leads a copy group, its followers copy the result like any other leader trade.

- [Set up](#set-up)
- [Request format](#request-format)
- [Symbols](#symbols)
- [Actions at a glance](#actions-at-a-glance)
- [buy / sell](#buy--sell): open or add to a position, with an optional bracket
- [close](#close): close one symbol, part of it, or the whole account
- [cancel](#cancel): cancel unfilled entry orders
- [breakeven](#breakeven): put a stop at the entry price
- [movestop](#movestop): move the one working stop to a price, an offset or a locked dollar amount
- [protect](#protect): multiple take-profits, stop legs, breakeven after TP1, auto-breakeven
- [Duplicate guard](#duplicate-guard)
- [Responses and errors](#responses-and-errors)
- [Pine Script](#pine-script)

## Set up

1. On the **Signals** page, click **+ New Token**. Pick the account the token trades on (**Route to Account**). "Auto" uses your first account.
2. Copy the URL. It looks like this:

   ```
   https://signaltradeapp.com/api/webhook/WEBHOOK_TOKEN
   ```

   The token is the only credential. Keep it secret. **Regenerate** gives you a new URL and the old one stops working at once. You can also disable a token, which refuses every alert sent to it.
3. In TradingView, open **Alerts → Create alert → Notifications**, tick **Webhook URL** and paste the URL.
4. Put **one** JSON payload from this page in the alert's **Message** box. Nothing else.

Every alert that reaches us is written to the **Signal Log** on the Signals page with its status (`EXECUTED`, `REJECTED` or `ERROR`) and a message. When an alert fails we also email you, at most once per token per hour.

> A token trades exactly one account. If your broker stops reporting that account (an evaluation was reset, breached or replaced), every alert is refused with `403 Account is inactive`. The Signals page flags the token; edit it to point at a live account.

## Request format

- `POST` to the token URL. Body: one JSON object.
- The `Content-Type` does not matter. TradingView sends `text/plain`; we parse the body as JSON anyway.
- `action` is case-insensitive. Numbers may be sent as JSON numbers or as strings (`"qty": "2"` works).
- A body that is not valid JSON is refused with `400 {"error":"Malformed JSON payload"}`. If it still contains TradingView placeholders such as `{{close}}` that TradingView did not fill in, the Signal Log says which ones.

## Symbols

Send the symbol on your chart. Both forms work:

| You send | Meaning |
|---|---|
| `MNQ1!`, `MNQ!`, `CME_MINI:MNQ1!` | TradingView continuous contract: the current front month |
| `MNQ` | Root: the current front month |
| `MNQZ6`, `MNQZ26`, `MNQZ2026` | That exact contract month |

The continuous form (`MNQ1!`, which is what `{{ticker}}` and `syminfo.ticker` give on a continuous chart) is the easiest: it follows the roll automatically.

- `MNQ2!` and deeper continuous months are refused. Only the front month can be resolved; send the exact contract instead (for example `MNQH7`).
- A symbol that cannot be mapped to a contract is refused with `400` and `"code": "UNKNOWN_SYMBOL"`, naming the symbol. Nothing is sent to the broker.
- For `close`, `cancel`, `breakeven`, `movestop` and `protect`, a root or continuous name matches **every** month of that root you hold. If you hold two months at once (during a roll), those actions are refused and ask for the full contract, for example `"symbol": "MNQZ6"`.

## Actions at a glance

| `action` | Needs | Does |
|---|---|---|
| `buy`, `sell` | `symbol`, `qty` | Places an order (market, limit or stop), optionally with a TP/SL bracket |
| `close` (also `flat`, `flatten`, `exit`) | nothing | No `symbol`: flattens the whole account. With `symbol`: closes that symbol. With `symbol` + `qty` or `percent`: closes part of it |
| `cancel` | nothing | Cancels unfilled **entry** orders (one symbol, or all). Stops and targets of open positions are kept |
| `breakeven` | `symbol` | Replaces the stop(s) with one full-size stop at the average entry price |
| `movestop` (also `move_stop`, `move-stop`) | `symbol` + one of `price`, `offsetPoints`, `lockUsd` | Moves the one working stop in place |
| `protect` | `symbol` + at least one of `tp`, `sl`, `autoBreakevenUsd`, `beAfterTp1` | Adds managed TP/SL legs to an open position. Needs **Managed protection** |

Anything else is refused with `400 Missing or invalid "action"`.

---

## buy / sell

Opens a position, adds to one, or reduces/reverses one, exactly like an order you place by hand.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `action` | `"buy"` \| `"sell"` | yes | | |
| `symbol` | string | yes | | See [Symbols](#symbols) |
| `qty` | number | yes | | Whole contracts. Decimals are cut down (`1.9` → 1). Below 1 is refused |
| `orderType` | `"market"` \| `"limit"` \| `"stop"` | no | `"market"` | Any other value is treated as market |
| `price` | number | for limit/stop | | Limit price, or stop trigger price. Ignored for market |
| `takeProfit` | number | no | | Absolute price of the take-profit leg |
| `stopLoss` | number | no | | Absolute price of the stop-loss leg |
| `beAfterTp1` | boolean | no | | Arms "stop to breakeven when the first target fills" for the position this order opens. See [protect](#protect) |
| `beOffsetTicks` | integer | no | `0` | With `beAfterTp1`: put the stop this many ticks past entry (0 to 20) |
| `allowDuplicate` | boolean | no | `false` | See [Duplicate guard](#duplicate-guard) |

**Sizing.** `qty` is the size on **this** account. Followers size from it with their own copy ratio. You never send follower sizes.

**Brackets and OCO.** Send `takeProfit` and/or `stopLoss` with any order type. The two exit legs are linked one-cancels-other at the broker: when one fills, the broker cancels the other. With a limit or stop entry, all three orders (entry, TP, SL) are working at once; the legs only become live protection when the entry fills.

Prices are absolute, not offsets. Make sure they are on the correct side: for a buy, TP above and SL below the entry.

**What the broker refuses is reported back.** The answer waits briefly for the broker to accept or refuse each bracket leg:

- Entry refused: `422` with `"code": "BROKER_ORDER_REJECTED"`. Nothing was placed.
- Entry placed but a leg refused: `409` with `"code": "BRACKET_INCOMPLETE"`, the `orderId`, and the `accepted` / `rejected` legs. **The position may be unprotected.** Check the account; do not resend the alert.
- A leg not confirmed in time: `200` with a `warnings` array. Check that it is working.

Linking two separate pending **entry** orders as OCO (a buy-stop and a sell-stop where one filling cancels the other) is not supported. Each alert places its own independent order.

### Examples

Market order:

```json
{"action": "buy", "symbol": "MNQ1!", "qty": 1}
```

Market order with a bracket:

```json
{
  "action": "buy",
  "symbol": "MNQ1!",
  "qty": 2,
  "orderType": "market",
  "takeProfit": 21080.00,
  "stopLoss": 20990.00
}
```

Limit entry with a bracket:

```json
{
  "action": "sell",
  "symbol": "ES1!",
  "qty": 1,
  "orderType": "limit",
  "price": 6050.25,
  "takeProfit": 6030.00,
  "stopLoss": 6060.00
}
```

Stop entry (breakout) with a bracket:

```json
{
  "action": "buy",
  "symbol": "NQ1!",
  "qty": 1,
  "orderType": "stop",
  "price": 21100.00,
  "takeProfit": 21160.00,
  "stopLoss": 21070.00
}
```

From a TradingView **strategy** alert (trigger "Order fills only"), TradingView fills in the side and size:

```json
{
  "action": "{{strategy.order.action}}",
  "symbol": "{{ticker}}",
  "qty": {{strategy.order.contracts}},
  "orderType": "market"
}
```

Success:

```json
{"success": true, "orderId": "616507970052"}
```

---

## close

| Field | Type | Required | Notes |
|---|---|---|---|
| `action` | `"close"` \| `"flat"` \| `"flatten"` \| `"exit"` | yes | All four mean the same |
| `symbol` | string | no | Without it the **whole account** is flattened |
| `qty` | number | no | With `symbol`: close only this many contracts |
| `percent` | number | no | With `symbol`: close this share of the position, above 0 and at most 100, rounded down |

### Close one symbol

```json
{"action": "close", "symbol": "MNQ1!"}
```

The broker closes whatever you hold in that symbol (it sizes the close itself, so no `qty` is needed) and that symbol's working orders are cancelled. Other symbols on the account are not touched.

```json
{"success": true, "flattened": false, "symbol": "MNQ1!", "closed": ["MNQZ6"], "cancelledOrders": 2}
```

If nothing is held, `closed` is empty and the alert still succeeds.

### Flatten the whole account

```json
{"action": "close"}
```

Every working order is cancelled and every position on the account is closed.

```json
{"success": true, "flattened": true}
```

> A `qty` with **no** `symbol` (`{"action":"close","qty":1}`) still flattens the whole account. Strategy templates often send a qty on every alert, so this is kept on purpose.

### Partial close

```json
{"action": "close", "symbol": "MNQ1!", "qty": 1}
```

```json
{"action": "close", "symbol": "MNQ1!", "percent": 50}
```

- A market order reduces the position. Followers copy it like any other order.
- Your stops and targets stay working. Any that are larger than what is left are resized down to the remaining size, so a triggered stop can never reverse the position.
- `percent` is rounded down to whole contracts. 50% of 3 closes 1. If the result is 0, nothing is sent and the alert is refused.
- A `qty` or `percent` at or above the position closes all of it, exactly like a plain close (working orders on the symbol are cancelled too).
- `qty: 0`, blank or non-numeric is treated as no qty, so `{{strategy.position_size}}` (which is 0 on an exit) still gives a full close.
- Send `qty` **or** `percent`, not both. `percent` needs a `symbol`.

```json
{"success": true, "symbol": "MNQZ6", "closedQty": 1, "remainingQty": 2, "orderId": "616507970101", "resizedOrders": 2}
```

If the close was not confirmed in time, or an exit order could not be resized, the answer carries a `warning`: check that no stop or target is larger than the position. If you hold nothing, the answer is `{"success": true, "symbol": "...", "closedQty": 0}`.

---

## cancel

Cancels **unfilled entry orders**, for example a limit that never filled.

```json
{"action": "cancel", "symbol": "MNQ1!"}
```

```json
{"action": "cancel"}
```

- With `symbol`: that symbol only. Without: every symbol on the account.
- An unfilled entry's own TP/SL legs go with it.
- **Exits are kept**: the stop and target of a position you hold, and any order on the closing side of a held position, are not cancelled. The position stays open. Use `close` to exit a filled trade.

```json
{"success": true, "action": "cancel", "symbol": "MNQ1!", "cancelledOrders": 1, "keptOrders": 2}
```

---

## breakeven

```json
{"action": "breakeven", "symbol": "MNQ1!"}
```

Puts **one** stop for the whole position at its average entry price, replacing the stop(s) you had. The take-profit is not touched.

- Refused (`400`) while the position is not in profit, or when the market is at or through the entry price: a stop there would fire at once. Your existing stop is left alone.
- This **cancels the old stop, then places the new one**, so there is a short moment with no stop. If the broker refuses the new stop, the previous one is put back and the alert is refused with `409` ("your stop is back at …"). In the rare case the old stop cannot be put back, you get `502` saying the position is **unprotected**.
- To move a stop without that gap, use [`movestop`](#movestop) with `"offsetPoints": 0`.

```json
{"success": true, "action": "breakeven", "symbol": "MNQZ6"}
```

---

## movestop

Moves the position's **one** working stop to a new level. The stop is **repriced**, not cancelled and re-placed.

| Field | Type | Notes |
|---|---|---|
| `action` | `"movestop"` | `"move_stop"` and `"move-stop"` also work |
| `symbol` | string | Required |
| `price` | number | An exact stop price |
| `offsetPoints` | number | Points from the **broker** average entry, toward profit. `0` = breakeven. Negative = on the loss side of entry |
| `lockUsd` | number | Dollars of profit to lock on the **whole position**, measured from the broker average entry. Negative = a loss you accept |

Send **exactly one** of `price`, `offsetPoints`, `lockUsd`.

```json
{"action": "movestop", "symbol": "MNQ1!", "offsetPoints": 0}
```

```json
{"action": "movestop", "symbol": "MNQ1!", "offsetPoints": 10}
```

```json
{"action": "movestop", "symbol": "MNQ1!", "lockUsd": 1740}
```

```json
{"action": "movestop", "symbol": "MNQ1!", "price": 21050.25}
```

**How the level is computed.**

- Offsets are measured from the broker's average fill price, never from TradingView's estimate.
- "Toward profit" means above entry for a long, below entry for a short.
- `lockUsd` is spread over the whole position: points = `lockUsd / (point value × contracts)`. Example: $1,740 on 2 NQ ($20 a point) is 43.5 points. `lockUsd` is refused for a contract whose dollar value per point is not known; send `price` or `offsetPoints` instead.
- The result is rounded to the tick, **away from the market** (down for a long, up for a short), so a rounded stop is never tighter than you asked.

**When it is refused.** The stop is left exactly where it was and the answer says so:

| Situation | Status |
|---|---|
| Not exactly one of `price` / `offsetPoints` / `lockUsd`, or not a number | `400` |
| No open position for the symbol | `400` |
| No working stop for the position | `400` |
| More than one working stop (for example a split stop from `protect`) | `409` |
| The new stop is at or through the market (it would trigger at once) | `400`, for example `"The market (27420.5) is at or below the new stop 27425, so it would trigger at once. Your stop was left at 27418.75."` |
| The broker did not take the new price | `409`, naming where your stop is now |
| Positions for the account have not loaded yet (just after a reconnect) | `503`, resend in a few seconds |

**Success:**

```json
{
  "success": true,
  "action": "movestop",
  "symbol": "MNQZ6",
  "orderId": "616507970311",
  "from": 21010.25,
  "price": 21030.0,
  "entry": 21020.0
}
```

| Field | Meaning |
|---|---|
| `orderId` | The id the stop rests under **now** |
| `from` | The stop's price before the move |
| `price` | The new stop price |
| `entry` | The broker average entry used (only with `offsetPoints` / `lockUsd`) |
| `unchanged` | `true` when the stop was already at that price; nothing was sent |
| `replaced` | `true` when the broker re-placed the stop under a new id (Rithmic) |
| `filled` | `true` when the moved stop filled at once and the position is closed |

**Broker behaviour you should know.**

- **Tradovate** reprices in place: the stop never leaves the book. If the stop is a bracket leg, Tradovate re-issues **both** legs under **new order ids** (same prices) after the **first** modify; later moves keep the id. The broker OCO link with the take-profit survives the modify, so a filled stop still cancels the take-profit. The `movestop` webhook handles the id change for you.
- **Rithmic** has no in-place modify. A move is a cancel plus a re-place, so the stop comes back under a new id and there is a very short window with nothing resting.
- **Managed protection ON:** Signal Trade App manages the legs itself. It detaches the stop from the broker OCO and cancels the take-profit when the stop fills.

**Staged stops** are two `movestop` alerts: for example breakeven at +$1,300 open profit, then lock $1,740 at +$2,540. See [recipes.md](recipes.md#staged-stop).

---

## protect

Builds a **managed** protection book on an open position: several take-profit legs, stop legs, "stop to breakeven after TP1" and auto-breakeven. Send it as a **second** alert, after the entry has filled.

> **Requires Managed protection.** Turn it on in **Settings → Trading** (or with the Managed protection switch in the order panel), while the account is flat. With it off, a `protect` alert that adds `tp` or `sl` legs is refused with `403` ("Protection management is turned off for this account").

| Field | Type | Notes |
|---|---|---|
| `action` | `"protect"` | |
| `symbol` | string | Required |
| `tp` | number or array of numbers | Take-profit prices. Each price becomes one leg |
| `sl` | number or array of numbers | Stop prices. Each price becomes one leg |
| `beAfterTp1` | boolean | When the first take-profit fills, move the stop to the entry price |
| `beOffsetTicks` | integer | With `beAfterTp1`: this many ticks past entry. 0 to 20, default 0 |
| `autoBreakevenUsd` | number | Move the stop to breakeven once the trade is this many dollars in profit |
| `autoBreakeven` | `true` | Same, using the default amount from your Settings |

At least one of `tp`, `sl`, `autoBreakevenUsd` or `beAfterTp1` is required.

**Sizing is automatic.** You never send quantities. The position is split evenly across the legs on each side (4 contracts and two targets = 2 + 2). A stop covers the whole position and shrinks as targets fill. If the position is too small to split into that many legs, the alert is refused with `400`.

**Order of work.** `beAfterTp1` is armed first, then stops are added, then targets, then auto-breakeven. A bad price anywhere in the list refuses the whole alert before anything is placed.

`autoBreakevenUsd` and `beAfterTp1` on their own need protection already on the position ("add a stop or target first").

### Examples

Scale out at two targets, stop for the whole position, stop to breakeven + 1 tick after TP1:

```json
{
  "action": "protect",
  "symbol": "MNQ1!",
  "sl": [20900],
  "tp": [21050, 21100],
  "beAfterTp1": true,
  "beOffsetTicks": 1
}
```

Three targets and auto-breakeven at $200:

```json
{"action": "protect", "symbol": "ES1!", "sl": 6020, "tp": [6045, 6055, 6065], "autoBreakevenUsd": 200}
```

Arm "breakeven after TP1" on the entry itself (it applies to the position this order opens):

```json
{"action": "buy", "symbol": "MNQ1!", "qty": 2, "beAfterTp1": true}
```

Success:

```json
{"success": true, "action": "protect", "symbol": "MNQZ6", "tp": 2, "sl": 1, "beAfterTp1": true, "beOffsetTicks": 1}
```

(`tp` and `sl` here are the number of legs added.)

---

## Duplicate guard

TradingView sometimes delivers one alert twice. If the **exact same payload text** arrives on the **same token** within **5 seconds**, it is executed once. The repeat is answered `200` and logged, but not executed:

```json
{"success": true, "duplicate": true, "executed": false, "message": "Duplicate alert ignored — ..."}
```

Any difference in the text makes it a different alert (another qty, another symbol, a `{{timenow}}` placeholder). If an alert really means to repeat itself, add:

```json
{"action": "buy", "symbol": "MNQ1!", "qty": 1, "allowDuplicate": true}
```

## Responses and errors

Success is `200` with `"success": true` and the fields shown for each action above.

Errors are a JSON object with an `error` message, sometimes with a `code`:

```json
{"error": "Could not resolve symbol \"XYZ1!\" to a tradable contract", "code": "UNKNOWN_SYMBOL"}
```

| Status | When |
|---|---|
| `400` | Malformed JSON; missing or invalid `action`, `symbol`, `qty`, `percent`; `UNKNOWN_SYMBOL`; invalid TP/SL price; no open position; refusals described above |
| `401` | Unknown webhook token |
| `403` | Token disabled; account locked (Risk page lockout or P&L lock) or inactive; Managed protection off (`protect`) |
| `409` | `BRACKET_INCOMPLETE`; more than one stop (`movestop`); breakeven refused and old stop restored; another protection change in progress |
| `422` | `BROKER_ORDER_REJECTED`: the broker refused the order. The message carries its reason |
| `502` | The broker gave no order id, or a breakeven left the position unprotected |
| `503` | No active broker connection; positions not loaded yet (resend in a few seconds); `TRADING_PAUSED`: a `buy` or `sell` during scheduled maintenance |
| `500` | Unexpected error |

Notes:

- A `200` for `buy`/`sell` means the order was **sent**. If the broker refuses it a moment later, the Signal Log entry is corrected to `REJECTED` and you are emailed.
- A locked account (Risk page lockout or the daily P&L lock) refuses every webhook action, including `close`, until the lock ends.
- During scheduled maintenance only **entries** are paused. A `buy` or `sell` answers `503`:

  ```json
  {"error": "Trading is paused for scheduled maintenance.", "detail": "New orders are not being accepted right now. You can still cancel orders, modify existing orders, and close or flatten open positions.", "code": "TRADING_PAUSED"}
  ```

  The alert is logged as `REJECTED` in the Signal Log and you get the usual failed-alert email. Nothing is sent to the broker and nothing is queued: the entry is not placed later. Every other action (`close`, `cancel`, `breakeven`, `movestop`, `protect`) keeps working during maintenance, so a webhook can still get you out of a position.

## Pine Script

TradingView fills placeholders like `{{ticker}}`, `{{strategy.order.action}}` and `{{strategy.order.contracts}}` only in the alert message box. Anything still in braces when it reaches us makes the JSON invalid.

For values your script computes (TP/SL levels, a timed exit), build the JSON in Pine and send it with `alert()`. Create the alert with the condition **"Any alert() function call"** (on a strategy: "Order fills and alert() function calls"). The text passed to `alert()` is the body that is sent to the webhook.

```pine
//@version=5
indicator("Webhook bracket", overlay=true)
tpPts = input.float(40, "Take-profit (points)")
slPts = input.float(20, "Stop-loss (points)")
longSignal = ta.crossover(ta.ema(close, 9), ta.ema(close, 21))
if longSignal
    tp = math.round_to_mintick(close + tpPts)
    sl = math.round_to_mintick(close - slPts)
    msg = '{"action":"buy","symbol":"' + syminfo.ticker + '","qty":1,"orderType":"market"'
    msg := msg + ',"takeProfit":' + str.tostring(tp) + ',"stopLoss":' + str.tostring(sl) + '}'
    alert(msg, alert.freq_once_per_bar_close)
```

A strategy can attach the JSON to each order with `alert_message`, and the alert message box then holds only `{{strategy.order.alert_message}}`:

```pine
strategy.entry("L", strategy.long, alert_message='{"action":"buy","symbol":"' + syminfo.ticker + '","qty":1}')
strategy.close("L", alert_message='{"action":"close","symbol":"' + syminfo.ticker + '"}')
```

Complete scripts are in [`examples/pine`](../../examples/pine):

| File | Shows |
|---|---|
| [`entry_with_bracket.pine`](../../examples/pine/entry_with_bracket.pine) | Indicator: market entries with TP/SL computed in Pine |
| [`staged_stop.pine`](../../examples/pine/staged_stop.pine) | Strategy: breakeven at +$X, then lock $Y at +$Z with `movestop` |
| [`cancel_unfilled_limit.pine`](../../examples/pine/cancel_unfilled_limit.pine) | Limit entry, `cancel` if not filled after N bars |
| [`session_flatten.pine`](../../examples/pine/session_flatten.pine) | `close` at a fixed New York time |
| [`scale_out_protect.pine`](../../examples/pine/scale_out_protect.pine) | Entry, then `protect` with two targets and `beAfterTp1` |
