# Chart and trading

The **/chart** page lets you place, move and protect orders directly on a TradingView chart inside Signal Trade App. If the account you trade leads a copy group, every fill is copied to its followers, the same as a trade placed in your broker platform.

Full guide with screenshots on the website: [How to trade from the chart](https://signaltradeapp.com/user-guide/chart-trading).

## What you need

| Requirement | Why |
|---|---|
| One connected **Rithmic** account | The chart's live market data comes through Rithmic, so the chart opens once a Rithmic account is connected. A prop firm Rithmic account or a Rithmic demo both work. |
| Any account to trade | Once the chart is open you can trade any of your connected accounts from it, **Tradovate included**. |
| Managed protection (optional) | Needed for several TP/SL legs, breakeven and trailing stops. See [Managed protection](managed-protection.md). |

A connected Propr account also opens the chart, with Propr markets and fractional sizes.

## The order panel

The panel on the right of the chart reads top to bottom:

1. **Account chip.** The account you are about to trade, whether it is DEMO or LIVE, and for a group leader how many followers will copy the order (for example *Leader → 3*). Tap it to switch account.
2. **Buy / Sell.** Each button shows the live price you trade against: Buy shows the ask, Sell shows the bid.
3. **Order type.** Market, Limit or Stop. For Limit and Stop, type a price or drag the line on the chart.
4. **Quantity.** Use the − / + stepper or a preset. Click *Edit presets* to set your own sizes.
5. **Bracket.** Switch on *Bracket Order* to attach a take-profit and stop-loss, **by price** or in **$ Amount** (the app works out the prices).
6. **Risk · Target · R:R.** What the bracket risks, what it targets and the reward-to-risk ratio.
7. **Place order.** The button spells out the full order, for example *Buy 2 Contracts @ 21,340.00*.

The 🔔 menu sets a **fill sound** (Chime, Ding, Bell, Beep, Pop or Off). Buys play slightly higher than sells. Every fill on the selected account also pops up as a message, for example *Filled: Bought 2 MNQZ6 @ 21,345.25*.

At the bottom of the panel, **Flatten account** and **Cancel all orders** act on the selected account. Each asks for a second click.

## Placing and moving orders on the chart

- **Right-click** the chart to place an order at that price. Below the market you get Buy Limit, Buy Limit + Bracket and Sell Stop. Above the market you get Sell Limit, Sell Limit + Bracket and Buy Stop. The order is filled into the ticket for you to check and place.
- **Drag** any working order, take-profit or stop line to move it. A large move asks you to confirm first.
- **Limit orders** can sit right next to the market.
- **Stop orders** too close to the market are nudged slightly away so the broker accepts them, and a message tells you the new price.
- A take-profit dragged **through** the market would fill at once, so the app asks you to confirm.
- Protective lines show what they lock in or risk in dollars (losses in red).

## Protecting a position

While you hold a position in the chart's symbol, the panel shows a **position box** with side, size, average price and stop coverage, for example *Stop covers 2/2*. If part of the position has no stop, it warns you in amber.

- With Managed protection **off**, use the bracket you attach when placing the order, and drag its lines to move them.
- With Managed protection **on**, you can add several TP and SL legs, move the stop to breakeven, set auto-breakeven and use a candle trailing stop. See [Managed protection](managed-protection.md).

## Orders and Positions panels

Below the chart:

| Panel | What it shows |
|---|---|
| **Open Orders** | Working orders. Edit the price (✎), quantity (✎), take-profit or stop-loss (✎ to edit, ✕ to remove, *+ TP* / *+ SL* to add), or cancel the order. Cancel asks for a second click. |
| **Filled** | Your fills with time, side, quantity, order type and fill price. |
| **Positions** | Side, size, average entry and open P&L, with a total row when you hold more than one. |

Switch between **This account** and **All accounts** at the top right of the panel.

## Account Info card

Under the order entry, the **Account Info** card shows the selected account's limits, so you can see what is left before you trade:

| Row | What it shows |
|---|---|
| **Progress** | Progress to the evaluation profit target, and how much is still to go. |
| **Daily Loss Limit** | How much of today's loss limit is left. Marked **broker** when the broker reports it, or **your rule** when you entered it. |
| **Max Loss Limit** | Drawdown left before liquidation, the drawdown type, and the threshold. |
| **Consistency** | Your best day as a % of total profit, against your firm's maximum. |
| **Trading days** | Days with realized P&L since the evaluation start, against the minimum. |
| **Flat by** | Your "be flat by" time. It turns amber within an hour and red within 15 minutes. |
| **Max contracts** | The broker's max order size, when it reports one. |

Click **Rules** to edit them on the Risk Mgmt page. The card never shows a guessed number: a row with nothing known is left out. If the broker reports no limits and you have entered none, the card asks you to add your firm's rules on the Risk page. See [Risk management](risk-management.md#prop-firm-rules).

## Trading from your phone

On a phone, a trade bar sits above the bottom menu with **Market Buy** and **Market Sell**, plus **Limit**, **Stop**, **Bracket** and the quantity. Pick a type, drag the preview line to your price, then tap **Trade**.

## Copy trading from the chart

If the selected account leads a copy group, every follower copies its **fills** at the follower's ratio, exactly like trades placed in your broker platform. Resting orders and their moves stay on the leader. The account chip shows *Leader → N* so you know when an order will be copied. See [Copy trading](copy-trading.md#what-gets-copied).

## Good to know

- Your TradingView drawings, styles and favourites are saved in your browser and come back the next time you open the chart.
- Practise on a demo account first, and always keep a way to manage your positions in your broker's own platform.
