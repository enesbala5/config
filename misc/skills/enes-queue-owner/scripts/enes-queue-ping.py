#!/usr/bin/env python3
"""Render Enes's twice-daily "what's waiting on you" ping, and keep a durable log of it.

Run by cron (--no-agent, stdout delivered verbatim to Telegram). Deterministic on purpose:
this must fire and read correctly even when nothing else in the stack is healthy.

Queue file:  /root/.hermes/workspace/enes-queue.json
Ping log:    /root/.hermes/workspace/enes-ping-log.md

Canonical source: misc/skills/enes-queue-owner/scripts/enes-queue-ping.py in the config repo.
Cron runs the deployed copy at /root/.hermes/scripts/enes-queue-ping.py — an edit here has to be
copied there, and both have to stay identical.

Format (Enes, 2026-09-13): terse, grouped by the bot that is blocked, one bullet per item,
link inline, no per-item explanation. The `detail` field stays in the queue for the owner;
it is deliberately NOT rendered.

Rules honoured here:
  - never invent items: an empty queue says so plainly
  - flag anything open 48h+ as ageing
  - the bullet number is the POSITION IN THIS PING (priority rank, then created) so
    "done 4" / "snooze 4 1d" keep resolving against what he actually read
  - the launch-checklist block is a fallback: shown only when the queue has
    nothing live, so the same item never appears twice in one ping
  - mark items as pinged so the log reflects reality
  - ALWAYS fire, including when nothing moved: a no-change ping says so in one line
    and still names the oldest item, so silence never gets read as "nothing to do"
    (and never as the scheduler being broken)
"""

import json
import os
import sys
from datetime import datetime, timezone

QUEUE = "/root/.hermes/workspace/enes-queue.json"
LOG = "/root/.hermes/workspace/enes-ping-log.md"
LAUNCH = "/root/.hermes/profiles/launch-buddy/workspace/coverlttr-launch-status.md"
TZ = "Europe/Tirane"

PRIORITY_RANK = {"high": 0, "normal": 1, "low": 2}

# Auto-shorten an `ask` when it carries no `short` field: cut at the first clause break.
CLAUSE_BREAKS = (" — ", " – ", " - ", "; ", ", or ", ", and ", " (")
SHORT_MAX = 78


def now() -> datetime:
    return datetime.now(timezone.utc)


def local(dt: datetime) -> datetime:
    try:
        from zoneinfo import ZoneInfo

        return dt.astimezone(ZoneInfo(TZ))
    except Exception:
        return dt


def parse(ts) -> datetime | None:
    if not ts:
        return None
    try:
        dt = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
    except Exception:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def age(created: datetime | None) -> str:
    if created is None:
        return "?"
    hours = max(0.0, (now() - created).total_seconds() / 3600)
    if hours < 1:
        return "<1h"
    if hours < 48:
        return f"{int(hours)}h"
    return f"{int(hours // 24)}d"


def short_ask(item: dict) -> str:
    """One glanceable line: the item's `short` if set, else the ask cut at a clause break."""
    text = str(item.get("short") or "").strip()
    if text:
        return text
    text = " ".join(str(item.get("ask") or "").split())
    for sep in CLAUSE_BREAKS:
        idx = text.find(sep)
        if idx > 8:
            text = text[:idx]
            break
    if len(text) > SHORT_MAX:
        text = text[: SHORT_MAX - 1].rstrip(" ,.;") + "…"
    return text


def open_launch_items() -> list[str]:
    """Unchecked boxes from the launch status file. Never fatal."""
    try:
        out = []
        for line in open(LAUNCH, encoding="utf-8"):
            stripped = line.strip()
            if stripped.startswith("- [ ] "):
                text = stripped[6:].split("  ←")[0].strip()
                if text:
                    out.append(text)
        return out
    except Exception:
        return []


def main() -> int:
    stamp = local(now())
    slot = "morning" if stamp.hour < 14 else "evening"

    try:
        data = json.load(open(QUEUE, encoding="utf-8"))
        items = data.get("items") or []
    except Exception as exc:
        print(f"Launch Buddy could not read the queue ({exc}). Nothing else to report.")
        return 0

    live = []
    for it in items:
        status = str(it.get("status") or "open").lower()
        if status == "done":
            continue
        if status == "snoozed":
            until = parse(it.get("snooze_until"))
            if until and until > now():
                continue
        live.append(it)

    live.sort(key=lambda it: (PRIORITY_RANK.get(str(it.get("priority") or "normal").lower(), 1),
                              parse(it.get("created")) or now()))

    # "No change" detection: every live item has already been pinged and nothing
    # was added/changed since the newest of those pings.
    pings = [parse(it.get("last_pinged")) for it in live]
    pings = [p for p in pings if p]
    last_ping = max(pings) if pings else None
    never_pinged = any(not it.get("last_pinged") for it in live)
    changed = bool(last_ping) and any(
        (parse(it.get("created")) or now()) > last_ping for it in live
    )
    quiet = bool(live) and last_ping is not None and not never_pinged and not changed

    lines = [
        f"Launch check — {stamp.strftime('%a %d %b')}, {stamp.strftime('%H:%M')}",
        "What's still on your hands right now?",
    ]
    if quiet:
        lines.append(f"No change since {local(last_ping).strftime('%H:%M')} ({age(last_ping)} ago).")

    if live:
        # Group by the bot that is blocked; numbering stays contiguous and IS the ping
        # position, so "done 4" resolves against what he actually read (queue.py mirrors
        # this exact order: priority rank, then created, regrouped by first appearance).
        order: list[str] = []
        grouped: dict[str, list[dict]] = {}
        for it in live:
            src = str(it.get("from") or "unassigned").strip() or "unassigned"
            if src not in grouped:
                grouped[src] = []
                order.append(src)
            grouped[src].append(it)

        idx = 0
        for src in order:
            lines += ["", src]
            for it in grouped[src]:
                idx += 1
                created = parse(it.get("created"))
                hours = (now() - created).total_seconds() / 3600 if created else 0
                flag = " ⚠️" if hours >= 48 else ""
                bullet = f"- {idx} · {short_ask(it)} ({age(created)} ago{flag})"
                link = str(it.get("link") or "").strip()
                if link:
                    bullet += f" — {link}"
                lines.append(bullet)

        start = live[0]
        lines += ["", f"Start here: {short_ask(start)}"]
    else:
        lines += ["", "Nothing is waiting on you. Queue is empty."]

    # Fallback only: with a live queue this block repeated items verbatim, so it
    # now appears only when the queue has nothing to say.
    launch = open_launch_items() if not live else []
    if launch:
        lines += ["", "Launch checklist still open:"]
        lines += [f"- {x}" for x in launch]

    if live:
        lines += [
            "",
            "Reply: done N · snooze N 1d · delegate N to <bot>",
            "Say the word and I will do the legwork on any of these.",
        ]

    text = "\n".join(lines)
    print(text)

    # Durable log + ping bookkeeping (best effort, never fatal).
    try:
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(f"\n## {stamp.isoformat(timespec='minutes')} ({slot})\n\n```\n{text}\n```\n")
        for it in live:
            it["last_pinged"] = now().isoformat(timespec="seconds")
        data["items"] = items
        data["updated"] = now().isoformat(timespec="seconds")
        tmp = QUEUE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        os.replace(tmp, QUEUE)
    except Exception:
        pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
