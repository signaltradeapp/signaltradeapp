# Live streams (SSE)

Two Server-Sent Events streams push changes to you as they happen. Use them instead of polling: the REST read endpoints are capped at 12 reads per minute per path, and the streams are not.

| Stream | What |
|---|---|
| [`GET /api/v1/stream`](#get-stream) | Orders, fills, positions, balances, drawdown, risk settings, locks and connection status |
| [`GET /api/v1/connection-health/stream`](#get-connection-healthstream) | Broker connection status only |

Both use the same `X-API-Key` header as the REST API. Any valid key works; no `trade` scope is needed.

## Wire format

Standard SSE. Every message is a single `data:` line holding one JSON object, followed by a blank line. There are no `event:` or `id:` lines; the kind of message is in the JSON's `type` field. Every message has `ts` (milliseconds since the epoch, server time).

```
data: {"type":"heartbeat","ts":1763389800000}

```

## GET /stream

```bash
curl -N -H "X-API-Key: $STA_API_KEY" -H "Accept: text/event-stream" \
  https://signaltradeapp.com/api/v1/stream
```

| Query | Notes |
|---|---|
| `accountId` | Optional. Only send events for this account. `404` if it is not yours |

### Events

| `type` | When | Rate |
|---|---|---|
| `snapshot` | First message after you connect | Once |
| `order` | An order was placed, changed, filled, cancelled or rejected | Every change |
| `fill` | An execution | Every fill |
| `position` | A position changed | At most once per second per account + symbol; latest value wins |
| `balance` | Balance, open P&L or today's realized P&L changed | At most once per second per account; latest value wins |
| `risk` | Remaining drawdown changed | When a value moves by $1 or more, at most once per second |
| `risk_settings` | Risk settings were saved | Every save |
| `lock` | The account was locked or unlocked, including when a lock runs out | Every change |
| `connection` | A broker connection changed status | Every change |
| `heartbeat` | Keep-alive | Every 15 seconds |

Every account event carries `accountId`: our account id, the same one the REST endpoints use.

### snapshot

Your starting state. After a reconnect it brings you fully up to date.

```json
{
  "type": "snapshot",
  "ts": 1763389800000,
  "accounts": [ { "id": "ACCOUNT_ID", "name": "MFFU50K-12345", "status": "ACTIVE" } ],
  "balances": [ { "accountId": "ACCOUNT_ID", "balance": 50349.44, "dayPnl": 349.44, "tradingDay": "2026-11-17" } ],
  "positions": [ { "accountId": "ACCOUNT_ID", "symbol": "MNQZ6", "side": "LONG", "qty": 2, "avgPrice": 21020.0, "openPnl": 37.5 } ],
  "orders": [ ],
  "risk": [ { "accountId": "ACCOUNT_ID", "equity": 50386.94, "liquidationLevel": 48300, "drawdownRemaining": 2086.94, "…": "…" } ]
}
```

- `balances[].dayPnl` is today's realized P&L **net of commissions** (the app's Day P&L).
- `orders` are the working orders, in the same shape as `order` events.
- `risk` holds the last drawdown reading per account. An account with no reading yet is left out; its first `risk` event follows soon after a change.

### order

```json
{
  "type": "order",
  "id": "616507970052",
  "accountId": "ACCOUNT_ID",
  "accountName": "MFFU50K-12345",
  "brokerId": "1234567",
  "symbol": "MNQZ6",
  "side": "Buy",
  "qty": 1,
  "price": 21000,
  "orderType": "Limit",
  "status": "OPEN",
  "takeProfit": 21050,
  "stopLoss": 20970,
  "timeInForce": "Day",
  "timestamp": "2026-11-17T14:29:58.000Z",
  "ts": 1763389798000
}
```

| Field | Meaning |
|---|---|
| `id` | Broker order id |
| `brokerId` | The broker's account id |
| `side` | `Buy` / `Sell` |
| `status` | `OPEN`, `FILLED`, `CANCELLED` or `FAILED` |
| `brokerStatus` | The broker's own terminal status when an order leaves the book: `Expired`, `Canceled` or `Rejected`. Tells a session-close expiry of a Day leg apart from a cancel |
| `filledPrice`, `filledAt` | Set once filled |
| `takeProfit`, `stopLoss` | Bracket levels, when the order has them |
| `ocoGroupId`, `bracketId`, `parentOrderId` | Grouping of bracket and OCO legs, when known |
| `timeInForce` | `Day` or `GTC` as the broker reports it; absent until the broker has said |
| `message` | Reason text, for example on a failure |

Orders and fills are never merged or delayed.

### fill

Same fields and same `id` as a row of [`GET /fills`](rest-api.md#get-fills).

```json
{
  "type": "fill",
  "id": "616507970099",
  "accountId": "ACCOUNT_ID",
  "accountName": "MFFU50K-12345",
  "brokerAccountId": "1234567",
  "orderId": "616507970052",
  "brokerFillId": null,
  "symbol": "MNQZ6",
  "side": "LONG",
  "action": "BUY",
  "qty": 1,
  "price": 21000,
  "fees": null,
  "timestamp": "2026-11-17T14:30:00.512Z",
  "ts": 1763389800600
}
```

`fees` and `brokerFillId` are filled in on `GET /fills` about 15 seconds later on Tradovate. Stream fill events carry no `cursor`; use `GET /fills` for that.

### position

```json
{"type": "position", "accountId": "ACCOUNT_ID", "symbol": "MNQZ6", "side": "LONG", "qty": 3, "avgPrice": 21013.33, "openPnl": 41, "ts": 1763389800700}
```

`qty: 0` (with `side: null`) means flat. `avgPrice` is the broker average entry. `openPnl` can be `null` when it is not known.

### balance

```json
{"type": "balance", "accountId": "ACCOUNT_ID", "balance": 50112.5, "openPnl": 41, "realizedPnl": 0, "ts": 1763389801000}
```

- A field can be missing or `null` when that update did not carry it. Keep your last known value.
- `realizedPnl` is the broker's own figure: **net** of commissions on Tradovate, **gross** on Rithmic. `dayPnl` in the snapshot and on `GET /accounts` is always net.

### risk

The Risk page's drawdown numbers. Same fields as `drawdown` in [`GET /accounts/{id}/risk`](rest-api.md#get-accountsidrisk).

```json
{"type": "risk", "accountId": "ACCOUNT_ID", "equity": 50153.5, "balance": 50112.5, "drawdownLimit": 2000, "drawdownType": "TRAILING", "peakBalance": 50300, "liquidationLevel": 48300, "drawdownRemaining": 1853.5, "source": "broker", "profitTarget": 3000, "targetBalance": 53000, "profitToPass": 2846.5, "ts": 1763389801100}
```

### risk_settings

Sent when risk settings are saved. Same fields as `GET /accounts/{id}/risk` (without `drawdown`).

### lock

```json
{"type": "lock", "accountId": "ACCOUNT_ID", "locked": true, "lockedUntil": "2026-11-17T23:00:00.000Z", "reason": "PNL_LIMIT", "ts": 1763389802000}
```

```json
{"type": "lock", "accountId": "ACCOUNT_ID", "locked": false, "lockedUntil": null, "ts": 1763400000000}
```

While locked, the account refuses new orders from the API and from webhooks.

### connection

```json
{"type": "connection", "connectionId": "CONNECTION_ID", "status": "RECONNECTING", "ts": 1763389803000}
```

Statuses: `CONNECTED`, `RECONNECTING`, `AUTH_EXPIRED`, `ERROR`, `DISCONNECTED`, `DISABLED`.

## GET /connection-health/stream

Broker connection status only.

```bash
curl -N -H "X-API-Key: $STA_API_KEY" -H "Accept: text/event-stream" \
  https://signaltradeapp.com/api/v1/connection-health/stream
```

It opens with a `heartbeat`, then one `snapshot` per connection, then a `status` event for every change:

```
data: {"type":"heartbeat","ts":1763389800000}

data: {"type":"snapshot","connectionId":"CONNECTION_ID","status":"CONNECTED","ts":1763389800010}

data: {"type":"status","connectionId":"CONNECTION_ID","status":"RECONNECTING","ts":1763389900000}

data: {"type":"status","connectionId":"CONNECTION_ID","status":"CONNECTED","ts":1763389930000}
```

| Status | Meaning |
|---|---|
| `CONNECTED` | Connected and trading |
| `RECONNECTING` | The connection dropped; we are reconnecting |
| `AUTH_EXPIRED` | The broker sign-in expired. Reconnect it on the Connections page |
| `ERROR` | A fatal error, for example a refused login |
| `DISCONNECTED`, `DISABLED` | Not connected |

The point-in-time version, with error messages, is [`GET /connections`](rest-api.md#get-connections).

## Limits and reconnecting

- **At most 5 open `/stream` connections per user.** A sixth answers `429` with code `TOO_MANY_STREAMS`. Close streams you no longer read.
- Opening a stream counts as one request toward the 120 requests per minute limit. Events do not count, and streams are not subject to the 12-reads-per-minute polling cap.
- A stream has no fixed lifetime. It stays open until you close it or the server restarts.
- A heartbeat arrives every 15 seconds. **If you receive nothing for 30 seconds, treat the stream as dead and reconnect.**
- On reconnect, the new `snapshot` replaces your state. Fills that happened while you were away are not replayed on the stream: call `GET /fills?after=<last cursor>` and deduplicate by `accountId` + `id`.
- Back off between reconnect attempts (for example 1, 2, 4 … up to 30 seconds) so a server restart does not hit the rate limit.
- Some HTTP clients buffer. Use `curl -N`, or read the response line by line.

## Python example (standard library only)

```python
import json, os, time, urllib.request

URL = "https://signaltradeapp.com/api/v1/stream"
KEY = os.environ["STA_API_KEY"]

def run():
    backoff = 1
    while True:
        req = urllib.request.Request(URL, headers={"X-API-Key": KEY, "Accept": "text/event-stream"})
        try:
            # 30 s read timeout: heartbeats arrive every 15 s, so silence means a dead stream.
            with urllib.request.urlopen(req, timeout=30) as resp:
                backoff = 1
                for raw in resp:
                    line = raw.decode("utf-8").strip()
                    if not line.startswith("data:"):
                        continue
                    event = json.loads(line[5:].strip())
                    if event["type"] != "heartbeat":
                        print(event["type"], event)
        except Exception as exc:  # timeout, network error, HTTP error
            print("stream dropped:", exc)
        time.sleep(backoff)
        backoff = min(backoff * 2, 30)

if __name__ == "__main__":
    run()
```

A complete example that reacts to `position` events is [`examples/python/staged_stop.py`](../../examples/python/staged_stop.py).
