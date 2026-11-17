# Brokers and prop firms

Signal Trade App connects to **Tradovate** and **Rithmic**, the two platforms most futures prop firms use. It also connects to **Propr** (crypto and stock perps, Beta). This page explains what connects how, what is not supported, and how to fix common connection errors.

## What you can connect

| Platform | Example prop firms | How it connects |
|---|---|---|
| **Tradovate** | Take Profit Trader, MyFundedFutures, Tradeify, LucidTrading and other Tradovate firms | Log in on Tradovate's own page (OAuth). No password or API key is stored by Signal Trade App. |
| **Rithmic** | Apex Trader Funding, Lucid Trading, Earn2Trade and other Rithmic firms | Rithmic username, password and system (your firm). |
| **Propr** (Beta) | Propr accounts | A Propr API key. |

**NinjaTrader:** there is no separate NinjaTrader connection. If your NinjaTrader account runs on Rithmic, connect it as Rithmic. If it is a Tradovate-cleared account, connect it as Tradovate. Trades you place in NinjaTrader are then copied like any other trade on that account.

**TradingView:** TradingView is not a connection. Alerts reach your accounts through a webhook. See [TradingView webhooks](../developers/tradingview-webhooks.md).

Full list on the website: [Which brokers and prop firms are supported](https://signaltradeapp.com/help/which-brokers-and-prop-firms-are-supported).

## Account types

| Account type | Supported? | Notes |
|---|---|---|
| Prop firm evaluation | Yes | Tradovate: pick the **Prop firm** environment. Rithmic: pick your firm as the system. |
| Prop firm funded / PA | Yes | Same settings as evaluations. Funded prop accounts live on the same environment. |
| Demo / sim | Yes | Tradovate: **Demo / Sim**. Rithmic: **Rithmic Paper Trading**. |
| Live (real-money) brokerage account | **No, for new connections** | Live accounts can no longer be added. A live connection that was added earlier keeps working and can still be reconnected. |

## Not supported

- **Live (real-money) brokerage accounts.** New live connections are refused, on Tradovate and on Rithmic (the numbered "Rithmic 01"-style live systems). Only prop firm and demo/sim accounts can be added.
- **Bulenox.** Bulenox's rules do not allow outside copy tools. If your username looks like a Bulenox login, the connection form tells you.
- **Topstep / TopstepX (ProjectX).** Signal Trade App does not connect to TopstepX. Topstep's terms require trading from your personal device and do not allow remote servers.

If your broker is not listed, email support@signaltradeapp.com with the broker name.

## Tradovate

1. **Connections → Add Connection → Tradovate.**
2. Choose the environment:
   - **Prop firm** for evaluation and funded prop firm accounts.
   - **Demo / Sim** for a Tradovate demo.
3. Click **Connect with Tradovate** and log in on Tradovate's page.

Notes:

- One Tradovate login can hold several accounts. They all appear under one connection.
- Tradovate logins expire from time to time. When a connection shows **AUTH_EXPIRED**, click **Re-authorize** and log in again.
- If a connection shows a warning that the last sign-in used a different Tradovate login, click **Re-authorize** and sign in with the right one.

## Rithmic

1. **Connections → Add Connection → Rithmic.**
2. Enter your Rithmic username and password. These are the credentials your firm gave you for Rithmic, which can differ from your NinjaTrader or firm dashboard login.
3. Choose the **System**:
   - **Rithmic Paper Trading** for a Rithmic demo.
   - Your prop firm from the list (for example Apex Trader Funding, Earn2Trade, Lucid Trading, Tradeify, The Trading Pit and others).
   - TradeSea systems are for FundYourEdge and other TradeSea firms only.
4. Click **Add Connection**.

Before you connect a brand-new Rithmic login, log in to **R|Trader Pro** once and accept the market data agreements. Rithmic refuses logins that have not accepted them.

## Propr (Beta)

Propr accounts connect with an API key from Propr (**Settings → Developer**, it starts with `pk_`). Create one key per Propr account. A Propr copy group holds Propr accounts only: you cannot copy between Propr and Tradovate or Rithmic. Set each follower's leverage at least as high as the leader's, because Propr refuses a copy that needs more margin than the follower has. Full guide: [Connect Propr](https://signaltradeapp.com/user-guide/connect-propr).

## Connection status

| Status | Meaning | What to do |
|---|---|---|
| **CONNECTED** | The connection is live. | Nothing. Also check that your accounts are listed. |
| **RECONNECTING** | The connection dropped and is coming back. | Wait up to 30 seconds. |
| **DISCONNECTED / ERROR** | The session was lost or the login was refused. Read the message on the card. | Fix the cause, then click **Reconnect**. |
| **AUTH_EXPIRED** | The Tradovate login needs renewing. | Click **Re-authorize** and log in to Tradovate. |

Each account under a connection also has a status. **LOCKED** means it is locked on the Risk Mgmt page (see [Risk management](risk-management.md)). **INACTIVE** means the broker no longer reports that account on this login.

The **Health** page shows every connection at a glance. Check it before the market opens.

## Common connection errors

| You see | Cause | Fix |
|---|---|---|
| Rithmic "permission denied" or **rp_code 13** | Wrong username or password, the wrong **System**, or a new login that has not accepted the R\|Trader agreements. | Check the username, password and system. Log in to R\|Trader Pro once and accept the market data agreements. Then click **Reconnect**. |
| "Rithmic refused the login … Check the username and password and that the account is still active" | Same as above, or the account was closed or expired by your firm. | Check with your firm that the account is active, then reconnect. |
| Tradovate CONNECTED but **no accounts** | The wrong environment, usually a prop firm account connected as Demo / Sim, or a personal live Tradovate account (not supported). | Delete the connection and add it again with **Prop firm**. Live accounts cannot be connected. |
| "The broker refused this connection (403)" | The account may be closed, expired or locked by your prop firm. | Check with your firm, then click **Reconnect**. |
| "Live (real-money) broker accounts can no longer be added" | You tried to add a live account. | Only prop firm and demo/sim accounts can be added. |
| "Broker connections are paused for maintenance" | A short maintenance window. | Try again in a few minutes. |
| Connection drops when you log in elsewhere | Some logins allow only one session at a time. | Avoid logging in to the same account from another tool while it is connected here. |
| Rithmic slow to connect at the open | Rithmic servers are busy. | Wait a minute and try again. |

When Rithmic keeps refusing a login, automatic retries slow down (to about every 30 minutes) and then stop, so a wrong password does not lock your account. After you fix the cause, click **Reconnect**.

## Weekends

Rithmic runs maintenance over the weekend. From Friday 5:00 PM ET, Signal Trade App does not try to reconnect a dropped Rithmic connection until **Sunday 5:30 PM ET**, half an hour before the futures open. You do not need to do anything. Disconnect emails are also held over the weekend while the market is closed. See [Troubleshooting](troubleshooting.md#my-rithmic-connection-dropped-over-the-weekend).

## Security

- Tradovate connects through Tradovate's login page. Signal Trade App never sees the password.
- Rithmic credentials and Propr API keys are stored encrypted.
- Never share your webhook URLs or API keys. They are credentials.
