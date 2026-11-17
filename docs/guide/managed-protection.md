# Managed protection

**Managed protection** lets Signal Trade App manage your stops and targets. It unlocks the chart's advanced tools: several take-profit and stop-loss legs on one position, stop to breakeven, auto-breakeven and candle trailing stops.

It is **off by default**. Turn it on only if you want those tools.

## On vs off

| | Off (default) | On |
|---|---|---|
| Who runs your take-profit and stop | Your broker. A bracket is sent as the broker's own take-profit and stop orders. | Signal Trade App. Your stops and targets are still real orders at your broker, but the app links, resizes and cancels them. |
| Take-profits and stops per position | One take-profit and one stop. | Several take-profit and stop legs, to scale out in pieces. |
| Change TP/SL on an open position from the chart | Move the bracket you attached. | Add, move or remove legs at any time. |
| Stop to breakeven, auto-breakeven | Not available | Available |
| Candle trailing stop | Not available | Available |
| If Signal Trade App or your connection goes down | Your broker keeps handling the bracket. | Orders already at the broker stay, but linking, resizing, breakeven and trailing moves may not happen. |

With it off, your orders stay exactly as you place them.

## What changes when it is on

- Each stop is linked to its target. When one fills, the other side is cancelled.
- Stops and targets are kept sized to your position.
- When you go flat, whatever is left is cancelled, **including stops and targets you placed in your broker's own platform**.

## Turn it on or off

You can only switch it while you are **flat**: no open positions and no working orders.

1. Close any positions and cancel working orders on your accounts.
2. Turn it on in one of two places:
   - The **🛡 Managed protection** switch in the chart's order panel.
   - **Settings → Managed protection**, switch **Let the app manage my stops and targets**.
3. If the switch is locked, it lists what is still open. Close those, then try again.

If an account is not connected when you switch, the app cannot check it. If that account comes back holding a trade, the app leaves that trade alone and tells you. It takes over from the next trade.

## Multiple take-profits and stops (scaling out)

With Managed protection on, the chart's position box shows your take-profit (TP) and stop-loss (SL) legs.

1. Type a price in the empty **TP** or **SL** row and press **+** to add a leg.
2. Add more legs to scale out in pieces. Each leg shows its size and the dollars it locks in or risks.
3. Change a leg by editing its price and pressing **Set**. Remove it with **✕**.
4. Tick **New TP/SL legs use the order qty** to size each new leg from the quantity box instead of splitting the side evenly.

The position box also shows coverage, for example *Stop covers 2/2*. If part of the position has no stop, it warns you in amber: *No stop — 1 contract unprotected*.

## Breakeven and trailing stops

Open **Breakeven & trailing** in the position box. Green badges show what is armed even when the section is folded.

| Tool | What it does |
|---|---|
| **Stop to breakeven** | Moves the whole stop to your entry price in one click. Available once the position is in profit. |
| **Auto-breakeven** | Makes the same move by itself when the trade reaches your profit amount, set in **$** or **points**. The amount is remembered per contract. |
| **Candle trailing stop** | Trails your stop behind the last closed candles. Pick the timeframe (1m, 5m, 15m, 30m or 1h) and how many candles to measure over. It needs a stop to trail. |

## From a TradingView alert

Webhook alerts can also set protection:

- `breakeven` moves the stop to your entry. It is refused while the position is not in profit.
- `protect` with several `tp` prices splits the position across the targets. With `beAfterTp1`, the stop moves to entry when the first target fills. This needs Managed protection **on**; with it off, the alert is refused.

Message formats are in [TradingView webhooks](../developers/tradingview-webhooks.md). Trailing stops are set on the chart, not from a webhook.

## How it works with copy trading

Managed protection acts on the account you trade: normally the **leader**.

- Followers do not hold their own take-profits or stops. When a leader leg fills, that fill is copied to the followers at their ratio, so a leader scaling out in three pieces makes the followers scale out in three pieces too.
- When the leader goes flat, Protect closes the followers (see [Copy trading](copy-trading.md#protect)).
- If you edit protection on a follower account from the chart, the app warns you: the follower's protection belongs to the leader.

## Important

When Managed protection is on, Signal Trade App, not your broker, links each stop to its target, cancels the other side when one fills, and makes resizing, breakeven and trailing moves. Your stops and targets still sit at your broker as real orders, but if Signal Trade App or your broker connection is down, those changes may not happen. Always keep a way to manage your positions in your broker's own platform.

Read the full [Risk Disclosure](https://signaltradeapp.com/risk-disclosure).
