# Copy trading

This page explains exactly what Signal Trade App copies, how follower sizes are worked out, and what happens in the edge cases: partial exits, reversals, reconnects, pausing and flattening.

## The basics

- A **copy group** has one **leader** and any number of **followers**.
- You trade the leader the way you normally do: in your broker platform, on the Signal Trade App [chart](chart-and-trading.md), with a [TradingView alert](../developers/tradingview-webhooks.md) or through the [API](../developers/rest-api.md).
- When an order on the leader **fills**, each follower gets a **market order** for the leader's filled size × the follower's ratio.
- It runs in the cloud, 24/7. Your computer does not need to be on.

## How follower size is calculated

> **Follower size = the leader's ORDER size × the follower's ratio.**

The follower's size always comes from the leader's order, never from positions. Signal Trade App does not look at what the leader or the follower holds and try to "match" it. Each entry, add, partial exit and close is its own order, sized the same way.

| Leader order | Ratio 1 | Ratio 2 | Ratio 3 |
|---|---|---|---|
| Buy 1 NQ | Buy 1 NQ | Buy 2 NQ | Buy 3 NQ |
| Sell 2 ES | Sell 2 ES | Sell 4 ES | Sell 6 ES |
| Long 4, sells 2 (partial exit) | Sell 2 | Sell 4 | Sell 6 |

Why this matters: if a follower is out of step with the leader (for example you traded it by hand), the next copied order is still the leader's order × ratio. It does not fix the difference. Check the follower in your broker if you see it out of step.

### Ratios

- The ratio is set per follower in the **Size × leader** column of the Cockpit.
- It is a **whole number from 1 to 100**.
- To copy at a smaller size, copy onto a micro contract instead: see [Mini to micro](#mini-to-micro-cross-order) below.
- Ratios below 1 are not generally available.
- You can only change a ratio while the leader and that follower have no open trade. A copy is sized with the ratio in force when it is sent, so changing it mid-trade would make the exit a different size from the entry.

On Propr, sizes are fractional (for example 0.003 BTC) and rounded to each market's size step. See [Connect Propr](https://signaltradeapp.com/user-guide/connect-propr).

## What gets copied

Every follower uses **Market Execution**. It is always on and there is no setting for it. Followers copy the leader's **fills**, not its resting orders.

| Leader does this | Every following follower |
|---|---|
| Market order fills | Gets a market order: leader size × ratio. |
| Places a limit or stop order | Nothing yet. Resting orders are not copied. |
| Moves (edits) a resting order | Nothing. |
| Cancels a resting order before it fills | Nothing. The follower never entered. |
| The limit or stop order fills | Gets a market order for the filled size × ratio. |
| Places a bracket (entry + take-profit + stop-loss) | Nothing until the entry fills. |
| Bracket entry fills | Enters at market. The take-profit and stop-loss stay on the leader only. |
| Moves its take-profit or stop-loss | Nothing. The leader's levels decide when everyone exits. |
| Take-profit or stop-loss fills | Exits. With Protect on, the follower is closed in that contract. With Protect off, the leader's exit is copied as a market order. |
| Partial fill | Each filled part is copied as it fills. |
| Partial exit (sells part of the position) | Copied: that part × ratio. |
| Reverses (for example short 1, buys 2) | Copied in full: the whole order × ratio. |

What this means for you:

- **Followers have no take-profit or stop-loss of their own.** That is expected. Their exit is the copied fill (or Protect). Keep the leader connected and keep Protect on.
- **Fill prices can differ.** Followers enter at market, so their fill can be a tick or so away from the leader's, especially when the leader used a limit order.
- If a broker refuses a leg of the leader's bracket (for example a stop on the wrong side of the market), the leader's bracket is incomplete and the followers have no exit until the leader exits. Check the leader after any rejection notice.
- Do not trade a follower by hand while it is following. A manual order on a follower is not part of the leader's trade.

## Protect

**Protect** is a per-follower switch in the Cockpit. It is **on by default** for new followers.

With Protect on:

- When the leader goes **flat** in a contract, the follower's position in that contract is closed by the broker and its working orders in that contract are cancelled.
- The leader's order that closes its **whole** position is not copied to that follower (Protect closes it instead).
- A **partial** close, or a **flip** to the other side, is still copied in full.

Protect also catches a follower that is still holding after the leader has exited, for example one that missed the entry or exit during a disconnect.

Turn Protect off only for a follower that you also trade by hand or with another tool. Protect closes whatever that follower holds in the contract when the leader goes flat.

With Protect off, every leader order is copied, including the close.

## Per-instrument rules

Each follower has one ratio. **Per-instrument rules** override it for specific instruments.

1. In the Cockpit, find the follower.
2. Under its **Size × leader** number, click **Set size per instrument**.
3. Add a row per instrument. Enter the instrument root (`NQ`, `ES`), not a contract month (`NQZ6`).
4. Set the size for that instrument (a whole number from 1 to 100), or leave it empty to use the follower's normal ratio.
5. Click **Save**. You can add up to 20 rows.

Instruments without a rule copy on the leader's contract at the follower's normal ratio. Rules are per instrument, so they keep working after every contract roll. Like ratios, rules can only be changed while the leader and that follower are flat.

Guide on the website: [Per-instrument rules and Cross Order](https://signaltradeapp.com/user-guide/per-instrument-rules-cross-order).

## Mini to micro (Cross Order)

A per-instrument rule can make the follower trade the micro when the leader trades the mini.

| Pair | Example |
|---|---|
| NQ ↔ MNQ | Rule NQ → MNQ ×10: leader buys 1 NQ, follower buys 10 MNQ (about the same dollar risk). |
| ES ↔ MES | Rule ES → MES with no size, follower ratio 2: leader buys 1 ES, follower buys 2 MES. |
| YM ↔ MYM | |
| RTY ↔ M2K | |

- The follower keeps the leader's contract month (NQZ6 → MNQZ6).
- Micro to mini is allowed but multiplies risk by ten. The setup screen warns you.
- Cross Order is for these equity index pairs only. Other markets (CL, GC and others) can have their own ratio but copy on the leader's contract.
- Protect and Flatten follow the crossed contract: when the leader goes flat in NQ, Protect closes the follower's MNQ.
- If the leader trades both NQ and MNQ with an NQ → MNQ rule, the leader's own MNQ trades also land in the follower's MNQ position.

## Inverse copy (Beta)

**Inverse Copy** is a per-follower switch. The follower trades the **opposite** direction: a leader buy becomes a follower sell. It is in Beta. Size and ratio work the same way. More: [Inverse copy](https://signaltradeapp.com/inverse-copy).

## Pausing a follower

Turn **Follow** off on a follower's row to stop copying to it without removing it from the group.

- No new orders are copied to it, including exits. If it holds a position when you pause it, manage that position yourself.
- Leader Flatten does not touch a paused follower.
- **Enable All Follow** in the Cockpit toolbar turns Follow back on for every follower.

To keep an account out of trading for a while (for example after a bad day, or during a session you do not trade), lock it instead on the Risk Mgmt page. A locked account is flattened and receives no copies. See [Risk management](risk-management.md#account-lockouts).

## Flatten

Each row in the Cockpit has a **Flatten** button.

- **Flatten on the leader** closes the leader's positions and, on every **following** follower, closes the contracts the leader held. Follower positions in other contracts, and paused followers, are not touched.
- **Flatten on a follower** closes only that follower. If its leader is still in a trade, the app first shows what the leader's next order would do to the now-flat follower, because that order will still be copied. For example, with Protect off, the leader's close would open a new position on the flat follower. Choose **Cancel** or **Flatten anyway**.
- **Cancel All Orders** in the Cockpit toolbar cancels working orders.

## Cross-broker groups

One group can mix Tradovate and Rithmic accounts: a Rithmic leader with Tradovate followers, the reverse, or any mix. Sizing and Protect work the same. Propr groups can only hold Propr accounts.

## Reconnects and session close

- If a broker connection drops, Signal Trade App reconnects it automatically.
- A follower that was disconnected when the leader traded does **not** catch up later. Fills from before the reconnect are not copied late, and old fills the broker re-sends after a reconnect are not copied again.
- Protect helps here: when the leader goes flat, a protected follower that is still holding is closed.
- After any disconnect, check each follower against its leader in the Cockpit. You also get a notification when a follower may be out of sync.
- Nothing is flattened automatically at the daily session close. Copying keeps running across sessions. The only automatic closes are the ones you set: Protect, the Daily P&L Lock and lockouts.
- Rithmic connections that drop over the weekend reconnect on Sunday at 5:30 PM ET. See [Brokers and prop firms](brokers-and-prop-firms.md#weekends).

## Speed

Orders are sent as soon as the leader's fill arrives: the website quotes under 50 ms to Tradovate and under 5 ms to Rithmic. The broker's own processing comes on top, and followers fill at market, so their fill price can differ slightly from the leader's.

If copies look slow, compare fill times in your broker, not the time your platform displays the order. A leader limit order that fills at your price and a follower market order a moment later can look like a delay of one tick.

## Prop firm limits

Every follower has its own limits, set by its prop firm or broker:

- **Max contracts**, usually by account size. A 50K account often allows fewer contracts than a 150K.
- **Daily loss and drawdown limits.** Once reached, the account may be locked or close-only.
- **Allowed products, trading hours and news rules.**

If a copied order breaks a limit, the broker refuses it and that follower no longer matches its leader. You get a "Copy failed" or "Copy skipped" email. Check that follower right away: if an entry was refused, a later copied close can open a position the leader does not have.

To avoid this, copy between accounts of the same size, keep the leader's size × ratio inside every follower's max contracts, or copy onto micros.

## Does copying break prop firm rules?

Copying between your own accounts is allowed by most prop firms. Some firms do not allow outside copy tools at all (Bulenox, which is not supported). Always check your firm's current rules.
