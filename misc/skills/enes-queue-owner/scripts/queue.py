#!/usr/bin/env python3
"""Manager's queue writer: answer Enes's ping commands against the live queue.

The number in his reply is the POSITION IN THE LAST PING, not the item id. This script
reproduces the renderer's live-filter and sort (priority rank, then created), so index N
means what he saw at line N.

    queue.py list
    queue.py done 3 [note...]
    queue.py snooze 3 1d [note...]
    queue.py delegate 3 to promoter

Writes are atomic (os.replace) and preserve every key, including ones this script does
not know about. Override the file with --queue PATH or $ENES_QUEUE (used by tests).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from datetime import datetime, timedelta, timezone

DEFAULT_QUEUE = "/root/.hermes/workspace/enes-queue.json"
PRIORITY_RANK = {"high": 0, "normal": 1, "low": 2}
DUR_RE = re.compile(r"^(\d+)([hdw])$")


def now() -> datetime:
    return datetime.now(timezone.utc)


def parse(ts):
    if not ts:
        return None
    try:
        dt = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
    except Exception:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def load(path: str) -> dict:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def live_items(data: dict) -> list[dict]:
    """Same filter, sort and owner-grouping as enes-queue-ping.py, so indexes match the ping.

    Order: priority rank, then created; then regrouped by owner in first-appearance order
    (the ping prints one block per owner, numbered contiguously across the blocks)."""
    live = []
    for it in data.get("items") or []:
        status = str(it.get("status") or "open").lower()
        if status == "done":
            continue
        if status == "snoozed":
            until = parse(it.get("snooze_until"))
            if until and until > now():
                continue
        live.append(it)
    live.sort(key=lambda it: (
        PRIORITY_RANK.get(str(it.get("priority") or "normal").lower(), 1),
        parse(it.get("created")) or now(),
    ))
    order, grouped = [], {}
    for it in live:
        src = str(it.get("from") or "unassigned").strip() or "unassigned"
        if src not in grouped:
            grouped[src] = []
            order.append(src)
        grouped[src].append(it)
    return [it for src in order for it in grouped[src]]


def save(path: str, data: dict) -> None:
    data["updated"] = now().isoformat(timespec="seconds")
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path) or ".", prefix=".queue.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        os.replace(tmp, path)
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def note(item: dict, text: str) -> None:
    stamp = now().date().isoformat()
    existing = str(item.get("notes") or "").strip()
    item["notes"] = f"{existing} {stamp}: {text}".strip() if existing else f"{stamp}: {text}"


def pick(live: list[dict], n: int) -> dict:
    if not 1 <= n <= len(live):
        raise SystemExit(f"no item {n}: the last ping carried {len(live)} live item(s)")
    return live[n - 1]


def cmd_list(path: str) -> int:
    data = load(path)
    live = live_items(data)
    if not live:
        print("no live items")
        return 0
    for idx, it in enumerate(live, 1):
        print(f"{idx}. [{it.get('priority')}/{it.get('kind')}] {it.get('id')}")
        print(f"   {it.get('ask')}")
        print(f"   from {it.get('from')} | status {it.get('status')} | created {it.get('created')}")
    return 0


def cmd_mutate(args) -> int:
    data = load(args.queue)
    item = pick(live_items(data), args.n)

    if args.action == "done":
        item["status"] = "done"
        item["snooze_until"] = None
        note(item, "closed by Enes via ping reply" + (f" - {args.note}" if args.note else ""))
    elif args.action == "snooze":
        m = DUR_RE.match(args.duration)
        if not m:
            raise SystemExit("duration must look like 12h, 1d or 2w")
        qty, unit = int(m.group(1)), m.group(2)
        delta = (timedelta(hours=qty) if unit == "h"
                 else timedelta(days=qty) if unit == "d" else timedelta(weeks=qty))
        until = now() + delta
        item["status"] = "snoozed"
        item["snooze_until"] = until.isoformat(timespec="seconds")
        note(item, f"snoozed {args.duration} by Enes until {until.date().isoformat()}"
                  + (f" - {args.note}" if args.note else ""))
    else:  # delegate
        words = [w for w in args.rest if w.lower() != "to"]
        if len(words) != 1:
            raise SystemExit("usage: delegate <n> [to] <bot>")
        who = words[0] if words[0].startswith("@") else "@" + words[0]
        item["status"] = "open"
        item["from"] = who
        note(item, f"delegated to {who} by Enes; item stays open until the work is verified done")

    save(args.queue, data)
    print(f"{args.action}: {item['id']} -> status={item.get('status')} from={item.get('from')} "
          f"snooze_until={item.get('snooze_until')}")
    print(f"live now: {len(live_items(load(args.queue)))}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--queue", default=os.environ.get("ENES_QUEUE", DEFAULT_QUEUE))
    sub = ap.add_subparsers(dest="action", required=True)
    sub.add_parser("list", help="show live items with their ping index")
    for name in ("done", "snooze"):
        p = sub.add_parser(name)
        p.add_argument("n", type=int, help="position in the last ping")
        if name == "snooze":
            p.add_argument("duration")
        p.add_argument("note", nargs="*", default=[])
    p = sub.add_parser("delegate")
    p.add_argument("n", type=int)
    p.add_argument("rest", nargs="+", help="'to <bot>' or '<bot>' — his phrasing is 'delegate <n> to <bot>'")

    args = ap.parse_args()
    if args.action == "list":
        return cmd_list(args.queue)
    if args.action in ("done", "snooze"):
        args.note = " ".join(getattr(args, "note", []) or []) or None
    return cmd_mutate(args)


if __name__ == "__main__":
    sys.exit(main())
