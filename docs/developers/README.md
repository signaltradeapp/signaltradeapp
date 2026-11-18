# Developer documentation

Signal Trade App is a cloud trade copier for futures prop-firm traders on **Tradovate** and **Rithmic**. Besides the website, you can drive it from code. This section covers every way to do that.

## What you can automate

| Interface | What it does | Auth | Page |
|---|---|---|---|
| **TradingView webhooks** | A TradingView alert (or any HTTP POST) opens, protects, moves the stop on, partially closes, cancels or closes a position on one account. Followers in your copy group copy the result. | Secret token in the URL | [tradingview-webhooks.md](tradingview-webhooks.md) |
| **REST API v1** | Read accounts, positions, working orders, trade history, fills, risk/drawdown and daily P&L. Place, modify and cancel orders, attach TP/SL, close one symbol or flatten an account. | `X-API-Key` header | [rest-api.md](rest-api.md) |
| **Live stream (SSE)** | One long-lived HTTP connection that pushes orders, fills, positions, balances, drawdown, locks and connection status as they change. Use it instead of polling. | `X-API-Key` header | [streaming.md](streaming.md) |
| **MCP server** | Lets Claude, Claude Code, Cursor and other MCP clients **read** your accounts, P&L, risk and copy groups. It cannot place, change or cancel orders. | Sign-in (OAuth) or API key | [mcp.md](mcp.md) |

Worked examples that combine these are in [recipes.md](recipes.md). Runnable files are in [`/examples`](../../examples):

- [`examples/curl`](../../examples/curl): one shell script per common REST call and webhook.
- [`examples/python/staged_stop.py`](../../examples/python/staged_stop.py): a staged stop (breakeven, then lock in profit) over the REST API and the stream. Standard library only.
- [`examples/pine`](../../examples/pine): Pine Script indicators and strategies whose `alert()` calls send the webhook JSON.

## Addresses

| What | URL |
|---|---|
| REST API base | `https://signaltradeapp.com/api/v1` |
| Live stream | `https://signaltradeapp.com/api/v1/stream` |
| Webhook | `https://signaltradeapp.com/api/webhook/WEBHOOK_TOKEN` |
| MCP server | `https://signaltradeapp.com/api/mcp` |
| Interactive OpenAPI (Swagger) | `https://signaltradeapp.com/api/docs` |
| OpenAPI JSON | `https://signaltradeapp.com/api/docs.json` |

## Which plan you need

- **Pro, $29/month flat**, unlimited accounts. New accounts start with a 5-day free trial.
- Placing, changing or cancelling orders through the REST API needs an active Pro subscription or free trial. Without one, those calls answer `403 PLAN_REQUIRED`.
- Read endpoints, the streams and the MCP server work with any valid API key.

## Before you start

1. Sign up at [signaltradeapp.com](https://signaltradeapp.com/register) and connect a broker on the **Connections** page.
2. For the REST API, the stream or MCP with a key: create a key on the **API Keys** page (`/api-keys`). Tick **trade** only if the key must place or change orders.
3. For webhooks: create a token on the **Signals** page (`/signals`) and copy its URL.
4. Test on a **demo / evaluation** account first. Demo accounts use the same order path as funded ones.

## Things to know up front

- **Supported brokers:** Tradovate and Rithmic accounts at prop firms that clear through them. **Bulenox is not supported.**
- **Real-money (live) brokerage accounts are not supported** for new connections. Use prop-firm evaluation, funded or demo accounts.
- **No market data.** The API has no quotes or candles. `GET /market/quotes/{symbol}` and `GET /market/candles` answer `403 MARKET_DATA_DISABLED`. Get prices from your broker or a data vendor.
- **Copying is automatic.** An order placed on a leader account through the API or a webhook is copied to its followers like any other leader order. You never place follower orders yourself.
- **Order ids are the broker's.** They can change when a bracket leg is modified (Tradovate) or when any order is modified (Rithmic). Re-read `GET /accounts/{id}/working-orders` before you act on an id. Never cache them.
- **Scheduled maintenance.** While order entry is paused for maintenance, new orders (REST orders, webhook `buy`/`sell`) are refused with `503`. Cancels, modifies, closes and flattens still work, through the REST API and through webhooks.
