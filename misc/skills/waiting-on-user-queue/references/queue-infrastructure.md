# This install's Enes queue — paths, jobs, delivery

Concrete map for the twice-daily "what is waiting on you" ping. Read this before touching the
queue, the log, or the cron jobs; re-verify each value with a read (they move) rather than
trusting this file as current.

## Files

| Thing | Path |
| --- | --- |
| Queue (single source of truth) | `~/.hermes/workspace/enes-queue.json` |
| Ping log (append-only, read before every reply) | `~/.hermes/workspace/enes-ping-log.md` |
| Renderer script | `~/.hermes/scripts/enes-queue-ping.py` |
| Launch task state (mine; the renderer also reads it for its checklist block) | `~/.hermes/profiles/launch-buddy/workspace/coverlttr-launch-status.md` |
| Job store to inspect | `~/.hermes/cron/jobs.json` |

The queue, the log and the renderer must not live under a profile directory: deleting that profile
takes the files with it and kills both pings silently. That is how this queue was lost once and then
relocated to `~/.hermes/workspace/`. The paths in the table above are current — re-verify them with a
read before trusting this file, and check that the renderer's `QUEUE`/`LOG` constants agree with them,
because a reader hardcoding an old path fails quietly while reporting success. Do not relocate the
queue, the log, or the jobs yourself: a move is the owner's call (@hermes, the only writer).

## Jobs

Two script-only jobs in the **default** profile's job store (that store is ticked by the always-on
gateway, which also holds the platform credentials):

- `[bot:launch-buddy] Queue ping — 10:00`
- `[bot:launch-buddy] Queue ping — 20:00`

`deliver: telegram` with no `origin` resolves to the configured home channel
(`telegram.home_channel` in `~/.hermes/config.yaml`), which is how the ping reaches Enes without a
per-job chat id. If a job instead carries `deliver: origin`, it needs `origin.chat_id` populated.

Schedule times read back in local time (+02:00 in this install) even though cron expressions are
generally UTC in this stack — confirm with the job's `next_run_at` rather than converting on paper.

## Firing-path health checks

```bash
stat -c '%y %n' ~/.hermes/cron/ticker_heartbeat ~/.hermes/cron/ticker_last_success
date -u                                   # heartbeat must be seconds old, not hours
ps -eo pid,etime,cmd | grep -i 'hermes gateway' | grep -v grep
```

Plus the job's own `next_run_at`, `last_run_at`, `last_status` and `deliver` in `~/.hermes/cron/jobs.json`.
A job with `last_run_at: null` has never executed, so nothing about it is verified yet.

## Render without side effects

```bash
python3 ~/.hermes/profiles/launch-buddy/skills/productivity/waiting-on-user-queue/scripts/verify-ping-render.py
```

It copies the queue, swaps the renderer's `QUEUE`/`LOG` constants for temp paths, execs the copy and
prints the delivered text plus the sandbox log and the stamped queue. Never run
`enes-queue-ping.py` directly to test it: it appends a real ping entry to the log Enes's history is
read from and stamps `last_pinged` on every live item.

## Renderer behaviour worth knowing

- An unreadable or missing queue prints `Launch Buddy could not read the queue (...)` and exits 0,
  so the failure arrives as if it were a normal check-in.
- Live items = `status: open`, plus `snoozed` whose `snooze_until` has passed. `done` never renders.
- Sort order is priority then `created`, then regrouped by owner (`from`); the first item becomes the
  `Start here:` line. The ping prints one block per owner with bullets numbered contiguously 1..N
  across the blocks, and `queue.py` in the owner's skill reproduces that exact order — so "done 4"
  means the fourth bullet he read, not the fourth row in the file.
- Format (set by Enes, 2026-09-13): terse. `Launch check — <day> <time>` / the one-line question /
  one `@owner` block per owner / `- <n> · <short> (<age> ago) — <link>`. It renders the item's `short`
  field and falls back to cutting `ask` at the first clause break; `detail` is never rendered.
- Cron delivery for these jobs carries no header or footer (`cron.wrap_response: false` in
  `config.yaml`), so the ping arrives as the script's own text, with no "Cronjob Response" / job_id
  block. If a ping suddenly grows that wrapper again, the config key was reverted.
- Items are flagged `⚠️` at 48h of queue age, computed from `created` — which is why a
  backdated `created` is a lie, and why a genuine `createdAt` from the forge is worth using.
- It appends the ping text to the log and rewrites the queue's `last_pinged` fields. Both are
  best-effort and never fatal, so a read-only filesystem degrades quietly.
- It renders unchecked `- [ ]` boxes from the launch status file only as a **fallback**, when no
  queue item is live. With a live queue the block is suppressed, so the same work cannot appear
  twice in one ping. Keep the fallback in mind when a queue happens to be empty.

## Coordinating with the queue owner

- **Before telling a peer their check was stale, compare mtimes.** A read that predates your write and a
  cached read produce the same symptom and need opposite fixes; asserting the wrong one teaches you to
  distrust a check that works. Message arrival order is not evidence of read order: a dropped and resent
  message lands long after the read it describes.

## Adding items by hand

Keep the file valid JSON and preserve the top-level keys the renderer rewrites (`items`, `updated`)
plus any keys the owner added. Field values wanted by the renderer: `ask`, `detail`, `from`,
`priority`, `status`, `created`, `snooze_until`, `last_pinged`. One imperative line in `ask`.
