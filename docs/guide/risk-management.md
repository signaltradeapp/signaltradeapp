# Risk management

A copier repeats a bad day on every account. The **Risk Mgmt** page gives each account its own limits so one losing session cannot take out all your evaluations.

| Tool | What it does | Closes positions? |
|---|---|---|
| [Daily P&L Lock](#daily-pl-lock) | Flattens and locks an account when its day hits your loss limit or profit target, until 6:00 PM ET. | Yes |
| [Account lockouts](#account-lockouts) | Locks an account during chosen sessions, or now for a set time. | Yes |
| [Drawdown and profit target tracking](#drawdown-and-profit-target-tracking) | Shows the drawdown left and the profit still needed to pass. | No |
| [Alerts](#alerts) | In-app notification and email when a line you set is reached. | No |
| [Protect](copy-trading.md#protect) | Closes a follower in a contract when its leader goes flat there. | Yes |

> Your prop firm's own daily loss limit, max drawdown and auto-liquidation are enforced by the firm at the broker, not by Signal Trade App. These tools help you stay inside them.

## Daily P&L Lock

Set your own daily loss limit, and optionally a daily profit target, per account. When the day reaches either one, Signal Trade App closes all positions, cancels working orders and locks the account until the next session opens at **6:00 PM ET**.

Available on **Tradovate and Rithmic** accounts (including prop firm accounts on them). Other connection types show a note that it is not available.

### Set it up

1. Open **Risk Mgmt** in the sidebar and find the account's card.
2. Under **Account Lockout**, enter a **Daily loss limit** in dollars (for example `500`).
3. Optional: enter a **Daily profit target** in dollars, to lock in a good day.
4. Choose what to **Count**:

   | Count | What is measured |
   |---|---|
   | **Realized + open (net)** (default) | Today's closed trades plus the open position's P&L. |
   | **Realized only (closed trades)** | Only closed trades. An open loser never trips it. |
   | **Open only (unrealized)** | Only the open position's P&L. |

5. Click **Save settings**.

The card shows today's realized and open P&L so you can see where you stand.

### When it trips

- All positions on the account are closed at market and working orders are cancelled.
- The account is locked until 6:00 PM ET. It receives no copies, and orders from webhooks and the API are refused.
- The card shows **LOCKED · P&L LIMIT** and you are notified.
- Until 6:00 PM ET you **cannot** unlock it, raise or remove the limit, or change Count. You can still tighten it. This is deliberate: it stops revenge trading after a bad day.

### Good to know

- It trips at most once per account per trading day. The trading day starts at 6:00 PM ET.
- It works per account. Each follower in a group can have its own limit.
- The close is a market order. In a fast market the fill can land past your limit, so set the limit inside your firm's limit, not right at it.
- An open-P&L breach must hold for a moment before it trips, so a single bad price print does not lock you. A realized loss locks at once.
- If the open P&L goes stale (no price for about 30 seconds while you hold a position), the lock pauses and tells you, rather than act on bad data.
- If a broker does not report realized P&L for an account, only **Open only** can be enforced there. The card tells you.

Overview on the website: [Daily P&L Lock](https://signaltradeapp.com/daily-loss-limit-lock).

## Account lockouts

A lockout takes an account out of trading. While an account is locked:

- All of its open positions are closed, in every contract.
- No copies are sent to it, and orders from webhooks and the API are refused.
- The card shows **LOCKED** and when the lock ends.
- The rest of the group keeps trading.

### Manual lockout

On the account's card, click **1 h**, **4 h**, **24 h** or **Permanent**. The account locks right away. Click **Unlock now** to end it early.

### Lock during sessions

Pick sessions you never trade, then click **Save settings**. The account locks automatically every day while those sessions run.

| Session | New York time |
|---|---|
| Asia | 20:00 – 04:00 |
| London | 03:00 – 11:00 |
| New York | 09:00 – 17:00 |

- Session locks are applied once a minute, so one can start up to a minute after the session opens.
- The lock ends when the session ends. If you unlock during a session, it stays unlocked for the rest of that session.

A lockout is something you set; it is not triggered by a loss. To lock automatically at a loss, use the [Daily P&L Lock](#daily-pl-lock).

## Drawdown and profit target tracking

Each account card shows how much drawdown is left before your firm's liquidation line and, for an evaluation, the profit still needed to pass. The numbers update live while you trade.

**This is for your information only.** It never closes a position, cancels an order, stops copying or locks the account.

### Set it up

1. When your broker reports the account's drawdown rule (Tradovate auto-liquidation, Rithmic risk settings), the numbers come straight from the broker and there is nothing to enter.
2. When it does not, enter your firm's rule under **Your prop firm's max drawdown**: the amount and the type, **Static**, **Trailing (real-time)** or **Trailing (end of day)**.
3. For an evaluation, enter the **Profit target** and the **Starting balance** (the account size, for example 50,000). Left empty, the current balance is used as the start.
4. Click **Save settings**.

### Reading the card

| You see | Meaning |
|---|---|
| Big number, **left before liquidation** | Drawdown remaining. The bar under it shrinks as you lose. |
| Green / amber / red | Green: more than half left. Amber: half or less. Red: 20% or less. |
| **to pass** / **Target reached** | Profit still needed for the evaluation target, or how far above it you are. |
| Equity | Balance plus open P&L. |
| Liquidated at | The equity at which your firm liquidates the account. |
| Peak | The highest balance a trailing drawdown counts from. |
| Type / Source | The drawdown rule, and whether it came from **Your broker** or **Your settings**. |

For some Rithmic accounts the numbers are shown only while the account is flat, because the broker does not confirm whether its balance already includes open P&L. The app shows no number rather than a wrong one.

### Prop firm rules

You can also enter rules that no broker reports: daily loss limit, consistency rule (best day as a maximum % of profit), minimum trading days, a "be flat by" time (New York time) and the evaluation start date. They are shown in the [Account Info card](chart-and-trading.md#account-info-card) on the chart. They are for your information only and never close trades.

## Alerts

Under **Alerts** on an account card, pick one of:

- **Drawdown left ≤**
- **Balance ≤**
- **Profit to pass ≤**

Enter a dollar amount and click **Add**. Alerts save right away.

- You get an in-app notification and an email once when the line is reached. The alert then shows **sent**.
- It re-arms when the account climbs back above the line, so a balance wobbling around it does not flood your inbox.
- Remove an alert with **✕**.
- Turn the emails off in **Settings → Notifications → Balance and drawdown alerts**.

An alert never closes a position or stops copying. If you want to stop trading when it fires, lock the account.

### Other notifications

In **Settings → Notifications** you can also turn on:

| Email | What you get |
|---|---|
| Broker connection lost | An email when a broker connection drops unexpectedly. Held over the weekend while the market is closed. |
| Trade execution alerts | An email when orders fill: copied trades only, or all trades. Off by default. |
| End of day summary | A daily recap of your trading. |

"Copy failed" emails have no switch. They are always sent.

## Suggested setup for prop accounts

| Account size | Max drawdown to enter | Suggested alert: Drawdown left ≤ |
|---|---|---|
| $50K evaluation | Your firm's rule (often $2,000–$2,500, trailing) | $750 |
| $100K evaluation | Your firm's rule (often $3,000–$3,500, trailing) | $1,000 |
| $150K funded | Your firm's rule (often $4,500–$5,000, trailing) | $1,500 |

Always check your firm's current rules.

- Set a **Daily loss limit** inside your firm's limit on every funded account.
- Add a drawdown alert on every account.
- Use **Lock during sessions** for sessions you do not trade.
- Keep followers within their firm's max contracts.
- Keep **Protect** on for followers you do not trade by hand.

Risk data is also available through the API: see [REST API](../developers/rest-api.md).
