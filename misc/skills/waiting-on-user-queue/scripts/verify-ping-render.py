#!/usr/bin/env python3
"""Render a cron ping script in a sandbox, without touching the real queue or log.

Why: a user-facing ping script's side effects ARE the record (it appends an entry to
 the person-facing log and stamps last_pinged on every live item). Running it in place
 to "test" it fabricates history the next session reads as real.

Usage:
  python3 verify-ping-render.py [--script PATH] [--queue PATH] [--log PATH] [--tmp DIR]
  python3 verify-ping-render.py --queue /path/to/other-queue.json   # other queue, same renderer

Defaults point at this install's Enes queue. Exit codes: 0 rendered, 2 paths not swappable.
"""

import argparse
import os
import shutil
import sys
import tempfile

DEFAULTS = {
    "script": "/root/.hermes/scripts/enes-queue-ping.py",
    "queue": "/root/.hermes/workspace/enes-queue.json",
    "log": "/root/.hermes/workspace/enes-ping-log.md",
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--script", default=DEFAULTS["script"])
    ap.add_argument("--queue", default=DEFAULTS["queue"])
    ap.add_argument("--log", default=DEFAULTS["log"])
    ap.add_argument("--tmp", default=None, help="sandbox dir (default: fresh temp dir)")
    args = ap.parse_args()

    if not os.path.exists(args.queue):
        print(f"WARNING: queue {args.queue} does not exist. The renderer will ship its "
              f"'could not read the queue' text to the person. Read it as a real finding.",
              file=sys.stderr)

    tmp = args.tmp or tempfile.mkdtemp(prefix="ping-verify-")
    os.makedirs(tmp, exist_ok=True)
    q_copy = os.path.join(tmp, "queue.json")
    l_copy = os.path.join(tmp, "ping-log.md")
    shutil.copy(args.queue, q_copy)

    src = open(args.script, encoding="utf-8").read()
    swapped = src.replace(f'"{args.queue}"', f'"{q_copy}"').replace(f'"{args.log}"', f'"{l_copy}"')
    if swapped == src:
        print("ERROR: neither the queue nor the log path appears as a quoted literal in "
              f"{args.script}, so the paths could not be swapped. Locate the constants "
              "(QUEUE/LOG) and set them here before running anything.", file=sys.stderr)
        return 2

    print("=== stdout (what would be delivered) ===")
    code = compile(swapped, args.script, "exec")
    try:
        exec(code, {"__name__": "__main__", "__file__": args.script})
    except SystemExit as exc:
        print(f"[exit code {exc.code}]")

    print("\n=== log entry in the sandbox copy ===")
    if os.path.exists(l_copy):
        print(open(l_copy, encoding="utf-8").read())
    else:
        print("(none: the script wrote no log — it most likely failed to read the queue)")

    print("\n=== sandbox queue after the run (last_pinged stamping) ===")
    print(open(q_copy, encoding="utf-8").read())

    print(f"\nreal files untouched:\n  {args.queue}\n  {args.log}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
