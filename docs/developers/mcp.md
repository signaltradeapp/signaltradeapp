# MCP server (read-only)

Signal Trade App runs a [Model Context Protocol](https://modelcontextprotocol.io) server so AI assistants can answer questions from your live account data: "What was my P&L this week across all accounts?", "How much drawdown does my evaluation have left?", "Why is my follower not copying?"

```
https://signaltradeapp.com/api/mcp
```

**It is read-only.** No tool can place, change or cancel an order, change a setting or move money. It sees exactly what a read API key sees over the [REST API](rest-api.md), and nothing more.

## Connect

### Claude (claude.ai and the Claude desktop app)

No key to copy. You sign in with your Signal Trade App account.

1. In Claude, open **Settings → Connectors** and click **Add custom connector**.
2. Name it `Signal Trade App` and paste `https://signaltradeapp.com/api/mcp` as the URL.
3. Click **Connect**, sign in to Signal Trade App and click **Allow**.
4. Ask, for example: "List my accounts and today's P&L."

Signing in creates a **read-scope API key** for the connector on your **API Keys** page (named after the app, for example "Claude (MCP connector)"). Delete that key to disconnect; access stops at once.

### Claude Code

```bash
claude mcp add --transport http signaltradeapp https://signaltradeapp.com/api/mcp
```

Then run `/mcp` in Claude Code to sign in through your browser.

### Cursor and other MCP clients (API key)

Create a key with the **read** scope on the API Keys page and send it as a bearer token. For example, Cursor's `mcp.json`:

```json
{
  "mcpServers": {
    "signaltradeapp": {
      "url": "https://signaltradeapp.com/api/mcp",
      "headers": { "Authorization": "Bearer ts_live_xxx" }
    }
  }
}
```

The server also accepts the key in an `X-API-Key` header. Give the MCP client its own read-only key; never a `trade` key.

## Tools

Each tool is one read of the REST API with your key. Money values are in the account currency (USD). Start with `list_accounts` to get account ids.

| Tool | Arguments | Returns | Same as |
|---|---|---|---|
| `get_user` | none | Your name, email, plan and timezone | `GET /user` |
| `list_accounts` | none | Every account: id, name, broker, environment, status, balance, today's P&L | `GET /accounts` |
| `get_positions` | `accountId` | Open positions with quantity, average price and open P&L | `GET /accounts/{id}/positions` |
| `get_working_orders` | `accountId` | Pending orders, read live from the broker | `GET /accounts/{id}/working-orders` |
| `get_trades` | `accountId`, optional `symbol`, `side` (`LONG`/`SHORT`), `since` (ISO time), `limit` (1 to 200, default 50) | Closed trades, newest first, with gross P&L, fees and net P&L | `GET /accounts/{id}/orders` |
| `get_fills` | optional `accountId`, `since`, `limit` (1 to 500, default 100) | Individual executions, oldest first | `GET /fills` |
| `get_risk` | `accountId` | Risk limits, lock state, the broker's risk rules where reported, remaining drawdown | `GET /accounts/{id}/risk` |
| `get_daily_pnl` | optional `accountId`, `from`, `to` (`YYYY-MM-DD`) | Realized P&L per trading day (6 PM to 5 PM ET), total and per account. Default last 30 days, at most 366 | `GET /pnl/daily` |
| `list_groups` | none | Copy groups: leader, followers, ratio, paused or not, inverse, delay, per-instrument rules | `GET /groups` |
| `list_connections` | none | Broker connections, status and error message | `GET /connections` |
| `get_recent_copies` | none | Last copy attempts (at most 10, within 24 hours) with result and latency | `GET /copies` |

All tools are marked read-only to the client.

## Limits

- **60 MCP requests per minute** per key (and 120 per minute per IP address). Over the limit: a JSON-RPC error "Rate limit exceeded".
- Every tool call is also a REST request with your key, so the [REST rate limits](rest-api.md#rate-limits) apply too, including at most 12 reads per minute of the same endpoint.
- A tool answer is cut at 200,000 characters. Narrow it with `limit`, `since` or `accountId`.
- Recent copies are kept for 24 hours, at most 10, and are emptied when the server restarts.

## Protocol details

- Streamable HTTP transport, **stateless**: `POST` JSON-RPC to `https://signaltradeapp.com/api/mcp`. There are no sessions and no server-initiated stream; `GET` and `DELETE` answer `405`.
- Without a key, the server answers `401` with a `WWW-Authenticate` header pointing at `https://signaltradeapp.com/.well-known/oauth-protected-resource`. MCP clients that support sign-in use it to start OAuth 2.1 (dynamic client registration, PKCE). The token issued is a read-scope API key.
- A REST error is passed back as a tool error with its HTTP status and message, for example `HTTP 404: Account not found (ACCOUNT_NOT_FOUND)`.

## Trading from an AI assistant

Not through MCP. To let your own code trade, use the [REST API](rest-api.md) with a `trade` key or [webhooks](tradingview-webhooks.md), and keep a human or hard limits in the loop.
