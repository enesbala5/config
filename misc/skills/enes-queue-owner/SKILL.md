---
name: enes-queue-owner
description: Use when answering Enes's queue ping (done/snooze).
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [queue, accountability, head-of-staff, enes, pings]
    related_skills: [waiting-on-user-queue, hermes-cron-pipelines, weekly-review-planning]
---

# Owning Enes's queue (head of staff role)

Use when Enes replies to a twice-daily ping ("done 3", "snooze 3 1d", "delegate 3 to promoter"), when
an agent reports something that needs him, or before answering any question about what is on his
plate. Manager (@hermes) is the SOLE WRITER of the queue; @launch-buddy and @promoter read it.

## Files (verify by reading, they move)

| Thing | Path |
| --- | --- |
| Queue (source of truth) | `/root/.hermes/workspace/enes-queue.json` |
| Ping log (append-only; read before replying) | `/root/.hermes/workspace/enes-ping-log.md` |
| Renderer (cron, script-only) | `/root/.hermes/scripts/enes-queue-ping.py` — canonical copy ships as `scripts/enes-queue-ping.py` in this skill; an edit must be copied to the deployed path |
| Job store | `/root/.hermes/cron/jobs.json` — jobs `[bot:launch-buddy] Queue ping — 10:00 / 20:00`, `deliver: telegram` → home channel |

Relocated 2026-09-12 out of `profiles/head-of-staff/workspace/` after that profile was deleted and
took the files with it. Never put this queue back under a profile directory: deleting the profile
silently kills both pings, and the failure ships as a normal-looking check-in.

Ping format and the owner-grouped ordering changed 2026-09-13 (see below); the peer copy of this
contract lives in `profiles/launch-buddy/skills/productivity/waiting-on-user-queue/references/queue-infrastructure.md`.

## Ping format (Enes's spec, 2026-09-13)

Terse, grouped by the bot that is blocked, link inline, no per-item explanation:

```
Launch check — Sun 13 Sep, 10:00
What's still on your hands right now?
[No change since 20:00 (14h ago).]      <- only when quiet

@promoter
- 1 · Confirm Opaque Screen is the wedge, or name the campaign (17h ago) — https://...

@launch-buddy
- 6 · coverlttr#104 onboarding: finish, rebase or close (9d ago ⚠️) — https://...

Start here: Confirm Opaque Screen is the wedge, or name the campaign

Reply: done N · snooze N 1d · delegate N to <bot>
Say the word and I will do the legwork on any of these.
```

- The renderer prints the item's `short` field; without one it cuts `ask` at the first clause break.
  `detail` is never rendered — it stays in the queue for the owner. Put the one-line imperative in
  `short` when adding an item; the full ask stays in `ask`.
- **Numbering is the bullet position in the ping**, ordered by priority rank then `created`, then
  regrouped by `from`. `queue.py` calls the same ordering, so both files must change together.
- Delivery carries no cron header/footer: `cron.wrap_response: false` in `/root/.hermes/config.yaml`.
  If a ping grows "Cronjob Response: ... (job_id: ...)" again, that key was reverted.

## Answering him

**The number in his reply is the POSITION IN THE LAST PING, not the item `id`.** The renderer sorts
live items by priority rank then `created`, so render order != file order. Use the script — it
reproduces the renderer's filter and sort, so index 3 means what he saw at 3.

```bash
python3 ~/.hermes/skills/productivity/enes-queue-owner/scripts/queue.py list
python3 ~/.hermes/skills/productivity/enes-queue-owner/scripts/queue.py done 3
python3 ~/.hermes/skills/productivity/enes-queue-owner/scripts/queue.py snooze 3 1d
python3 ~/.hermes/skills/productivity/enes-queue-owner/scripts/queue.py delegate 3 to promoter
```

- `done` → `status: done` (item stops rendering forever). Only after verified completion — a PR
  merged or closed, a credential present, a decision named. "I'll do it" is not done.
- `snooze <n> <dur>` (12h/1d/2w) → `status: snoozed` + `snooze_until`; renders again after that.
- `delegate <n> to <bot>` → `from` becomes `@<bot>` and the note says who took it and when, but the
  STATUS STAYS `open`: delegated work that still needs his sign-off is still on his plate.
- Every command appends a dated note to the item and rewrites the file atomically (`os.replace`).
  Never hand-edit the JSON with a text tool: a truncated queue makes the renderer print its error as
  the next ping.
- After acting, confirm in one line what moved and what is left. No recap of the whole queue.

## Standing rules

1. **Read the queue AND the ping log before answering anything about his plate.** The log is the
   only record of what was actually asked and when; the queue alone cannot tell you.
2. **Never invent or silently drop an item.** An item that arrives from another agent (ASK / WHY /
   LINK) gets checked against existing items first: enrich the existing item rather than duplicating
   it, and say which one you folded it into. A duplicate is noise on the one channel that must stay
   worth reading.
3. **Never approve, merge, spend, publish or decide on his behalf.** Queue it and keep the ask to one
   imperative line.
4. **Close items that stopped mattering** (someone else took the work — e.g. @promoter took the launch
   banners, so that item was closed rather than left ageing).
5. **Moving the queue or the jobs is a coordinated change**: renderer constants, both cron jobs, and
   every agent that reads it. Never leave a reader pointing at a dead path.

## Verifying the ping

Never run `enes-queue-ping.py` directly to test it — it appends a real ping entry to the log and
stamps `last_pinged`, fabricating history the next session reads as real. Copy the script, swap its
`QUEUE`/`LOG`/`LAUNCH` constants to temp paths, run the copy, and check the real files are
byte-identical (sha256 before/after). Cover three cases: first ping (nothing stamped), **no change**
(all items already stamped, none newer than the newest `last_pinged` → the ping must open with the
"No change since your last check-in" line and still list everything), and all-done (the checklist
fallback block must still appear).

If you do run the real renderer by accident, undo both side effects before doing anything else:
delete the appended `## <ts> (<slot>)` section from the log and reset every `last_pinged` to `null`
(plus `updated` to its previous value), writing the queue atomically.

**A ping must fire even when nothing changed.** Enes wants the check-in whether or not there is news
(standing instruction, 2026-09-13) — the cadence is what keeps him accountable, so silence is the
failure mode. A quiet ping states "no change" first, then lists the open items with their ages and
names the oldest as "start here"; it never reads as "nothing to do", and a disabled job is never
alouded to look like a real check-in.

## Recovering lost files

Deleting a Hermes profile destroys its workspace. File contents survive in the agent session
transcripts: `<profile>/state.db` (or a peer profile's db), table `messages`, column `tool_calls`,
which stores full `write_file` arguments verbatim.

```python
import sqlite3, json
con = sqlite3.connect("file:/root/.hermes/profiles/<any>/state.db?mode=ro", uri=True)
for rid, tc in con.execute("select rowid, tool_calls from messages where tool_calls like ?", ("%<filename>%",)):
    for c in json.loads(tc):
        print(c["function"]["name"], c["function"]["arguments"][:200])
```

## Pitfalls

- Replying from the item `id` when the number he typed was a rendered position.
- A scheduled job left `paused`/`enabled: false` (or `last_run_at: null`) is a silent failure: Enes
  reads "no ping" as "nothing on my plate". Check both jobs' `enabled` state whenever the cadence
  comes up, and verify a real fire landed (Telegram delivery, not just a script run).
- Letting a peer's skill or doc keep the old queue path after a relocation — tell the reader to
  update, then re-check that it did.
- Adding a second source of the same work to the ping (a checklist doc repeating queue items);
  the renderer shows the checklist block only when the queue is empty, keep it that way.
- The fallback parses the status file one line at a time and trims each `- [ ]` line at `  ←`, so a
  checkbox line that WRAPS leaves its annotation text in the ping (and a dangling dash if the
  annotation is alone on the continuation line). Keep every checkbox and its note on one line.
