# Getting started

This page takes you from a new account to your first copied trade. Plan on about 15 minutes.

You need:

- Two or more prop firm or demo accounts on **Tradovate** or **Rithmic**. One will be the **leader** (the account you trade), the others **followers** (the accounts that copy it).
- A card for the free trial.

## 1. Create your account

1. Go to [signaltradeapp.com/register](https://signaltradeapp.com/register).
2. Enter your name, email and a password, or sign up with Google.
3. Open the verification email and click the link. Until you verify, a banner in the app reminds you, and alerts may not reach you.
4. Start the 5-day free trial. A card is required, but you are not charged until the trial ends. See [Billing](billing.md).

## 2. Connect a Tradovate account

Tradovate accounts connect through Tradovate's own login page. Signal Trade App never sees your Tradovate password.

1. In the app, open **Connections** and click **Add Connection**.
2. Choose **Tradovate** as the broker and give the connection a name, for example `Tradeify-Eval-1`.
3. Pick the **Environment**:

   | Environment | Use it for |
   |---|---|
   | **Prop firm** | Evaluation **and** funded accounts from a prop firm. Prop firms keep both on Tradovate's sim environment. |
   | **Demo / Sim** | A Tradovate demo account. |

4. Click **Connect with Tradovate** and log in on the Tradovate page that opens.
5. Back on Connections, check that the status is **CONNECTED** and that your accounts are listed under the connection.

> If the connection is CONNECTED but lists no accounts, the environment is usually wrong. Delete the connection and add it again with **Prop firm**. See [Troubleshooting](troubleshooting.md#my-connection-shows-0-accounts).

## 3. Connect a Rithmic account

Rithmic accounts (Apex Trader Funding, Lucid Trading and many other firms) connect with your Rithmic username and password. NinjaTrader accounts that run on Rithmic connect as Rithmic.

1. On **Connections**, click **Add Connection** and choose **Rithmic**.
2. Enter a display name, your Rithmic **username** and **password**.
3. Pick the **System**: the firm that gave you the login (an Apex account is **Apex Trader Funding**), or **Rithmic Paper Trading** for a Rithmic demo.
4. Click **Add Connection**. Rithmic can take 10 to 30 seconds to log in.
5. Check that the status is **CONNECTED** and your accounts are listed.

The wrong system is refused as "permission denied", even with the right password. If the form warns that your username looks like a different firm's login, use the system it suggests. More fixes are in [Brokers and prop firms](brokers-and-prop-firms.md#common-connection-errors).

## 4. Create a copy group

A copy group is one leader and any number of followers.

1. Open the **Cockpit** and click **New Group**.
2. Enter a group name and pick the **Leader Account**.
3. Tick the **Follower Accounts** that should copy it, then click **Create Group**.
4. In the group table, set each follower's **Size × leader** (the copy ratio). At 1 the follower trades the same size as the leader. At 2 it trades double. Ratios are whole numbers from 1 to 100.
5. Check that **Follow** is on for each follower.
6. Leave **Protect** on (it is on by default). When the leader goes flat in a contract, Protect closes the follower in that contract too. See [Copy trading](copy-trading.md#protect).

The first time you start copying, the app shows a short note about broker and account limits. Read it: every follower's prop firm sets its own max contracts and loss limits.

## 5. Place your first copied trade

Use a demo or evaluation account for this test.

1. Place a 1-contract market order on the leader. You can use your broker platform (Tradovate, NinjaTrader, R|Trader), the Signal Trade App [chart](chart-and-trading.md), or a TradingView alert.
2. When the leader's order fills, every follower that is following gets a market order for the leader's size × its ratio.
3. Close the leader's position. Every follower goes flat too.

## 6. Check that it worked

- **Cockpit:** each follower row shows the position it holds. During the trade, every follower should hold the leader's size × its ratio, on the same side.
- **Orders panel** (in the Cockpit): today's orders with their status. A **Failed** order shows the broker's message.
- **Email:** if an order could not be copied to a follower, you get a "Copy failed" or "Copy skipped" email. These are always sent.
- **Journal:** after the trade closes, it appears in the [Journal](journal-and-analytics.md), marked **own** on the leader and **copy** on followers.

If a follower did not copy, see [Troubleshooting](troubleshooting.md#a-trade-was-not-copied).

## Next steps

- Set a daily loss limit on each account: [Risk management](risk-management.md).
- Learn exactly what is and is not copied: [Copy trading](copy-trading.md).
- Trade from TradingView alerts: [TradingView webhooks](../developers/tradingview-webhooks.md).
- Turn on connection-loss and execution emails in **Settings → Notifications**.
