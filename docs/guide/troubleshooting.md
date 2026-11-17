# Troubleshooting

Answers to the problems traders ask about most. If yours is not here, see [Where to get help](#where-to-get-help).

## A trade was not copied

Check these in order:

1. **Is the follower connected?** In the Cockpit, the dot next to the account should be green. A follower that is not connected cannot receive copies. Click **Reconnect** on the Connections page.
2. **Is Follow on?** A follower with **Follow** off receives nothing, including exits.
3. **Is the account locked?** A locked account (manual lockout, session lockout or Daily P&L Lock) receives no copies. Check the Risk Mgmt page.
4. **Did the leader's order fill?** Followers copy **fills**. A resting limit or stop order on the leader is not copied until it fills, and a cancelled one is never copied. See [Copy trading](copy-trading.md#what-gets-copied).
5. **Is the account in the group you traded?** The leader must be the account the order went to. For TradingView alerts, check which account the webhook token routes to.
6. **Did the broker refuse it?** Look for a **Failed** order in the Cockpit's Orders panel, or a "Copy failed" / "Copy skipped" email. See [The broker refused an order](#the-broker-refused-an-order).
7. **Was there a disconnect?** A follower that was disconnected when the leader traded does not catch up later. Bring it in line by hand in your broker platform. Protect closes it when the leader goes flat.
8. **Is your plan active?** When a trial or subscription ends, copy groups are removed. See [Billing](billing.md#what-happens-when-a-plan-ends).

## The follower's size is wrong

- **Follower size = leader order size × ratio.** It is never based on positions. Check the follower's **Size × leader** and any [per-instrument rule](copy-trading.md#per-instrument-rules) for that instrument.
- **A rule crosses the contract.** With NQ → MNQ, the follower trades MNQ, at its own ratio.
- **The follower was already out of step.** If you traded the follower by hand, or an earlier copy was refused, the next copy is still leader order × ratio. It does not fix the difference. Fix the follower in your broker.
- **Partial fills.** Each filled part of the leader's order is copied as it fills, so a follower can briefly show a partial size.
- **The broker capped it.** A copy above the follower's max contracts is refused by the broker. You get an email.
- **Inverse Copy is on.** The follower trades the opposite side.

## The broker refused an order

The broker or prop firm refuses an order when it breaks one of the account's limits, for example:

- More contracts than the account allows (common when copying a large account onto a smaller one).
- The daily loss limit or drawdown is reached, so the account is locked or close-only.
- The product, trading hours or news rules are not allowed.
- A stop on the wrong side of the market.

The refusal message is shown on the **Failed** order in the Orders panel (on the chart, as a red message), and you get a "Copy failed" email for a follower.

**Check that follower right away.** If an entry was refused, a later copied exit can open a position the leader does not have. Keep the leader's size × ratio inside every follower's limits, or copy onto micros.

## My connection shows 0 accounts

| Platform | Likely cause | Fix |
|---|---|---|
| Tradovate | A prop firm account connected with **Demo / Sim**. | Delete the connection and add it again with the **Prop firm** environment. |
| Tradovate | A **personal live Tradovate account** (your own real-money brokerage account). Live accounts are not supported, so there is nothing to list on the prop firm or demo environment. | Live accounts cannot be connected. Use prop firm or demo accounts. |
| Rithmic | The wrong **System**, or the account was closed by your firm. | Check the system matches the firm that gave you the login. |

Read the message on the connection card too: a connection can be CONNECTED and still have a problem, such as no accounts.

## My connection is disconnected

1. Read the message on the connection card.
2. Fix the cause (password, system, agreements, expired account), then click **Reconnect**.
3. For Tradovate **AUTH_EXPIRED**, click **Re-authorize** and log in to Tradovate again.

Common messages and fixes are in [Brokers and prop firms](brokers-and-prop-firms.md#common-connection-errors). In short:

- **Rithmic "permission denied" / rp_code 13:** wrong username or password, the wrong System, or a new login that has not accepted the R|Trader agreements. Log in to R|Trader Pro once, accept the agreements, then reconnect.
- **"The broker refused this connection (403)":** the account may be closed, expired or locked by your firm.

Turn on **Broker connection lost** emails in **Settings → Notifications** to hear about drops right away. The **Health** page shows all your connections at once.

## My Rithmic connection dropped over the weekend

That is normal. Rithmic runs maintenance over the weekend and drops connections. Signal Trade App holds reconnects from Friday 5:00 PM ET until **Sunday 5:30 PM ET**, half an hour before the futures open, then reconnects automatically. You do not need to press Reconnect. Connection-loss emails are also held while the market is closed.

If a connection is still down after Sunday 6:00 PM ET, read its message and click **Reconnect**.

## A follower has a position the leader does not

This happens when a follower got out of step: an entry was refused, it was disconnected, or it was traded by hand. To fix it:

1. Close the extra position on the follower, with **Flatten** on its Cockpit row or in your broker.
2. Find the cause in the Orders panel or your emails.
3. Keep **Protect** on for followers you do not trade by hand. It closes a follower that is still holding when the leader goes flat.

The app also notifies you when a follower may be out of sync with its leader.

## Followers have no take-profit or stop-loss

That is expected. Followers copy the leader's fills and hold no stops or targets of their own. When the leader's take-profit or stop fills, the followers exit too. See [Copy trading](copy-trading.md#what-gets-copied).

## Copies look slow

Copies are sent as soon as the leader's fill arrives. Followers fill at **market**, so if the leader used a limit order, the follower's price can be a tick or so different. That looks like a delay but usually is not. Compare fill times in your broker, not what your platform displays.

## I cannot change a ratio or a per-instrument rule

Ratios and rules can only be changed while the leader and that follower have no open trade. Close the trade (or wait for it to end), then change it.

## I cannot turn Managed protection on or off

You can only switch it while you are flat on your accounts: no positions and no working orders. The switch lists what is still open. See [Managed protection](managed-protection.md#turn-it-on-or-off).

## My account is locked and I cannot unlock it

A **Daily P&L Lock** cannot be unlocked, raised or removed until the next session opens at 6:00 PM ET. That is by design. A manual or session lockout can be ended with **Unlock now**. See [Risk management](risk-management.md).

## I cannot add a live account

New live (real-money) brokerage accounts are not supported. Only prop firm and demo/sim accounts can be added. Live connections added earlier keep working.

## I cannot connect Bulenox

Bulenox is not supported: its rules do not allow outside copy tools.

## Orders are refused during maintenance

During an announced maintenance window, new entries can be paused. Exits, cancels and Flatten always keep working, so you can always get out of a position.

## A TradingView alert did nothing

Check the signal log on the **Signals** page. **REJECTED** rows say why (invalid JSON, a missing field, a locked account or a broker refusal). No row at all means the alert never reached us: check the webhook URL in the alert. See [TradingView webhooks](../developers/tradingview-webhooks.md).

## Where to get help

- Help center: https://signaltradeapp.com/help
- User guides on the website: https://signaltradeapp.com/user-guide
- Email: support@signaltradeapp.com. Include the account name (not your password), the symbol, and the time it happened.
- Bugs and feature requests: open an issue in this repository. Never post passwords, API keys or webhook URLs in an issue.
