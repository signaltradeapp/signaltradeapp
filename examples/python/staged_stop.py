#!/usr/bin/env python3
"""
Staged stop for Signal Trade App over the REST API v1. Python 3.8+, standard library only.

  Stage 1: when open profit reaches +$1,300, move the stop to breakeven.
  Stage 2: when open profit reaches +$2,540, move the stop to lock in $1,740.

    export STA_API_KEY=ts_live_xxx            # a key with the "trade" scope
    python3 staged_stop.py watch --account ACCOUNT_ID --symbol NQ \
        --stage 1300:0 --stage 2540:1740

    # or a single move right now (lock $0 = breakeven):
    python3 staged_stop.py move --account ACCOUNT_ID --symbol NQ --lock-usd 0

How it works, before EVERY move:
  1. GET  /accounts/{id}/positions       -> side, qty and avgPrice (the broker's average entry)
  2. GET  /accounts/{id}/working-orders  -> the ONE stop protecting that position
  3. compute avgPrice +/- lockUsd / (point value x qty), rounded to the tick AWAY from the market
  4. PUT  /accounts/{id}/orders/{stopId} {"price": ...}

Order ids are never cached: on Tradovate a bracket leg is re-issued under a new id after its
first modify, and on Rithmic every modify returns a new id. "watch" learns open P&L from the
live stream (GET /stream, "position" events), so it does not poll.

The API has no market data, so a move that would put the stop through the market is refused
by the broker (HTTP 400) and the stop stays where it was. The script then reports and keeps
watching. A simpler alternative with no code: the webhook "movestop" action.

This is an example. Run it against a demo or evaluation account first.
"""
import argparse
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.request

BASE = os.environ.get("STA_BASE_URL", "https://signaltradeapp.com/api/v1").rstrip("/")

# Dollar value of one point, and the tick size, for common CME contracts.
# Pass --point-value and --tick for anything else.
CONTRACTS = {
    "ES": (50.0, 0.25), "MES": (5.0, 0.25),
    "NQ": (20.0, 0.25), "MNQ": (2.0, 0.25),
    "YM": (5.0, 1.0), "MYM": (0.5, 1.0),
    "RTY": (50.0, 0.1), "M2K": (5.0, 0.1),
    "CL": (1000.0, 0.01), "MCL": (100.0, 0.01),
    "GC": (100.0, 0.1), "MGC": (10.0, 0.1),
}

MONTH_CODES = "FGHJKMNQUVXZ"


class ApiError(Exception):
    def __init__(self, status, body):
        self.status = status
        self.body = body
        msg = body.get("error") if isinstance(body, dict) else body
        if isinstance(msg, dict):
            msg = "{} ({})".format(msg.get("message"), msg.get("code"))
        super().__init__("HTTP {}: {}".format(status, msg))


def api_key():
    key = os.environ.get("STA_API_KEY")
    if not key:
        sys.exit("Set STA_API_KEY to an API key with the trade scope.")
    return key


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("X-API-Key", api_key())
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            parsed = json.loads(raw)
        except ValueError:
            parsed = raw
        raise ApiError(e.code, parsed)


# ── symbols ──────────────────────────────────────────────────────────────────

def root_of(symbol):
    """'NQ1!' / 'CME_MINI:NQ1!' / 'NQZ6' / 'NQ' -> 'NQ'."""
    s = re.sub(r"1?!$", "", symbol.upper().split(":")[-1].strip())
    m = re.match(r"^([A-Z0-9]+?)[{}]\d{{1,4}}$".format(MONTH_CODES), s)
    return m.group(1) if m and re.search(r"[A-Z]", m.group(1)) else s


def matches(wanted, held):
    """A root/continuous name matches every month of that root; a contract only itself."""
    held = str(held or "").upper()
    if wanted.upper() == held:
        return True
    is_contract = re.search(r"[{}]\d{{1,4}}$".format(MONTH_CODES), wanted.upper()) is not None
    return (not is_contract) and root_of(held) == root_of(wanted)


# ── reading the account ──────────────────────────────────────────────────────

def read_position(account, symbol):
    rows = call("GET", "/accounts/{}/positions".format(account))["data"]
    held = [p for p in rows if matches(symbol, p.get("symbol")) and float(p.get("qty") or 0) > 0]
    if not held:
        return None
    if len(held) > 1:
        raise RuntimeError("{} is held in several contracts ({}); pass the exact contract".format(
            symbol, ", ".join(p["symbol"] for p in held)))
    return held[0]


def order_type(o):
    return str(o.get("orderType") or o.get("ordType") or "").lower().replace(" ", "")


def order_side(o):
    return str(o.get("action") or o.get("side") or "").capitalize()


def order_price(o):
    for k in ("stopPrice", "price", "triggerPrice"):
        v = o.get(k)
        if isinstance(v, (int, float)):
            return float(v)
    return None


def find_the_stop(account, contract, side):
    """The ONE working stop protecting this position. Re-read every time: ids change."""
    closing = "Sell" if side == "LONG" else "Buy"
    rows = call("GET", "/accounts/{}/working-orders".format(account))["data"]
    stops = [o for o in rows
             if str(o.get("symbol", "")).upper() == contract.upper()
             and order_type(o) in ("stop", "stopmarket")
             and order_side(o) == closing]
    if len(stops) != 1:
        raise RuntimeError("expected exactly one working stop on {}, found {}".format(contract, len(stops)))
    return stops[0]


# ── the move ─────────────────────────────────────────────────────────────────

def snap_away_from_market(price, tick, side):
    """Round to the tick, down for a long's stop and up for a short's: never tighter than asked."""
    ticks = price / tick
    if abs(ticks - round(ticks)) < 1e-6:
        n = round(ticks)
    else:
        n = math.floor(ticks) if side == "LONG" else math.ceil(ticks)
    decimals = len(repr(tick).split(".")[1]) if "." in repr(tick) else 0
    return round(n * tick, decimals)


def move_stop(account, symbol, lock_usd, point_value, tick):
    pos = read_position(account, symbol)
    if pos is None:
        print("no open position for {}: nothing to move".format(symbol))
        return False
    side, qty, entry = pos["side"], float(pos["qty"]), float(pos["avgPrice"])
    contract = pos["symbol"]
    direction = 1 if side == "LONG" else -1
    target = snap_away_from_market(entry + direction * lock_usd / (point_value * qty), tick, side)

    for attempt in (1, 2):
        stop = find_the_stop(account, contract, side)
        current = order_price(stop)
        if current is not None and abs(current - target) < 1e-9:
            print("stop on {} already at {}".format(contract, target))
            return True
        # Never loosen a stop that a previous stage (or a human) already tightened.
        if current is not None and (target - current) * direction < 0:
            print("stop on {} at {} is already tighter than {}: left alone".format(contract, current, target))
            return True
        try:
            res = call("PUT", "/accounts/{}/orders/{}".format(account, stop["id"]), {"price": target})
        except ApiError as e:
            # A stale id (re-issued bracket leg): re-read once and retry against the stop resting now.
            if attempt == 1 and e.status in (400, 404, 409) and "no longer" in str(e).lower():
                time.sleep(1.5)
                continue
            print("move refused, stop left at {}: {}".format(current, e))
            return False
        data = res.get("data", {})
        print("{} {} {} -> {} (entry {}, lock ${}){}".format(
            contract, side, current, target, entry, lock_usd,
            " [re-placed under a new id]" if data.get("replaced") else ""))
        # Let a bracket re-issue settle before anything reads the ids again.
        time.sleep(2)
        return True
    return False


# ── watch: stages driven by the live stream ──────────────────────────────────

def stream_events(account):
    """Yield stream events forever, reconnecting with backoff. 30 s of silence = dead stream."""
    backoff = 1
    url = "{}/stream?accountId={}".format(BASE, account)
    while True:
        req = urllib.request.Request(url, headers={"X-API-Key": api_key(), "Accept": "text/event-stream"})
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                backoff = 1
                for raw in resp:
                    line = raw.decode("utf-8").strip()
                    if line.startswith("data:"):
                        yield json.loads(line[5:].strip())
        except Exception as exc:  # timeout, network drop, HTTP 429 ...
            print("stream dropped ({}), reconnecting in {}s".format(exc, backoff), file=sys.stderr)
        time.sleep(backoff)
        backoff = min(backoff * 2, 30)


def watch(args, point_value, tick):
    stages = sorted(args.stage, key=lambda s: s[0])
    done = set()          # stage indexes already applied to the current position
    position_key = None   # (contract, side, avgPrice): a new position resets the stages
    print("watching {} on account {}: {}".format(args.symbol, args.account, ", ".join(
        "at +${:g} lock ${:g}".format(t, l) for t, l in stages)))

    def on_position(p):
        nonlocal done, position_key
        if not matches(args.symbol, p.get("symbol")):
            return
        if not p.get("qty"):
            if position_key:
                print("{} is flat".format(p.get("symbol")))
            position_key, done = None, set()
            return
        key = (p.get("symbol"), p.get("side"), p.get("avgPrice"))
        if key != position_key:
            position_key, done = key, set()
        pnl = p.get("openPnl")
        if pnl is None:
            return
        for i, (trigger, lock) in enumerate(stages):
            if i not in done and pnl >= trigger:
                print("open P&L ${:.2f} >= ${:g}: lock ${:g}".format(pnl, trigger, lock))
                try:
                    move_stop(args.account, args.symbol, lock, point_value, tick)
                except (RuntimeError, ApiError) as e:
                    print("not moved: {}".format(e))
                done.add(i)   # one attempt per stage per position; a refused move is not retried

    for ev in stream_events(args.account):
        if ev.get("type") == "snapshot":
            for p in ev.get("positions", []):
                on_position(p)
        elif ev.get("type") == "position":
            on_position(ev)


# ── command line ─────────────────────────────────────────────────────────────

def parse_stage(s):
    try:
        trigger, lock = s.split(":")
        return float(trigger), float(lock)
    except ValueError:
        raise argparse.ArgumentTypeError("stage must be TRIGGER_USD:LOCK_USD, e.g. 1300:0")


def main():
    ap = argparse.ArgumentParser(description="Staged stop over the Signal Trade App REST API.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("move", "watch"):
        p = sub.add_parser(name)
        p.add_argument("--account", required=True, help="account id from GET /accounts")
        p.add_argument("--symbol", required=True, help="root (NQ), continuous (NQ1!) or contract (NQZ6)")
        p.add_argument("--point-value", type=float, help="dollars per point for one contract")
        p.add_argument("--tick", type=float, help="tick size")
    sub.choices["move"].add_argument("--lock-usd", type=float, required=True,
                                     help="dollars to lock on the whole position (0 = breakeven)")
    sub.choices["watch"].add_argument("--stage", type=parse_stage, action="append", required=True,
                                      help="TRIGGER_USD:LOCK_USD, repeatable")
    args = ap.parse_args()

    known = CONTRACTS.get(root_of(args.symbol))
    point_value = args.point_value or (known[0] if known else None)
    tick = args.tick or (known[1] if known else None)
    if not point_value or not tick:
        sys.exit("unknown contract {}: pass --point-value and --tick".format(args.symbol))

    if args.cmd == "move":
        ok = move_stop(args.account, args.symbol, args.lock_usd, point_value, tick)
        sys.exit(0 if ok else 1)
    watch(args, point_value, tick)


if __name__ == "__main__":
    main()
