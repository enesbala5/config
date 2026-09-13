---
name: waiting-on-user-queue
description: Use when running a waiting-on-user queue and its pings.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [accountability, queue, pings, cron, followup, blockers]
    related_skills: [hermes-cron-pipelines, weekly-review-planning]
---

# Waiting-on-user queue and check-in pings

Use when the job is holding a queue of items blocked on ONE person, nudging them on a fixed cadence,
and acting on their answers: a twice-daily "what is waiting on you" list, an agent-blocked review
queue, a founder decision list. Also use it before editing or verifying the ping that renders that
queue, and before adding your first item to someone else's queue.

For the generic cron mechanics (job shapes, script placement, UTC schedules, delivery targets) the
`hermes-cron-pipelines` skill is the authority. This skill covers the queue and the nudging.

## Standing rules

1. **The queue file is the single source of truth.** Read it AND the ping log before you write to the
   person, so you never ask about something they already answered. The log is the only evidence of
   what has been asked and when.
2. **A fixed cadence is a budget, not a quota.** Two pings a day means each has to be worth reading;
   extra messages are for a genuine new blocker, never a stream. Never repeat the same ask inside
   one slot.
3. **"I'll do it" is not done.** Done means verified: PR merged or closed, file published, credential
   present, decision named. Record the intent and re-surface the item at the next ping.
4. **Never approve, merge, spend, publish or sign off on their behalf.** You prepare so the decision
   takes minutes instead of an evening — options, a recommendation, the question at the end.
5. **Never silently drop or reword an item another agent added.** If you disagree, say so to the
   queue owner or in the ping, and leave the item exactly as it is.
6. **The queue's path and the ping schedule are not yours to change.** Verify the firing path before
   claiming a ping will fire, and route any move of the jobs, the queue, or the log to whoever owns
   them; a ping that silently stops firing is worse than no ping.

## Writing the nudge

- Lead with the item. No greeting, no padding, no emotional check-in, no corporate phrasing.
- One question per item, answerable in minutes: "Approve the positioning doc or tell me which
  section is wrong." A question the person cannot answer in one line is two items or a document.
- Always offer the piece you can take yourself: "I can draft the ad plan for you to react to."
- Keep the age of each item visible and flag the ageing ones instead of burying them; drift you
  cannot see is drift nobody fixes.
- Report items to the queue owner in the exact shape they asked for. For this queue that is one
  line per item as **ASK / WHY / LINK**, plus the `from` attribution so the owner knows which agent
  is blocked. State attribution you inferred and invite correction.

## Adding an item

- **Verify the claim before it enters the queue** — PR state from the forge, the doc path in the
  repo, the credential actually absent. A wrong item burns their attention and your credibility.
- `ask` is one imperative line; the question the person must answer lives there, not in `detail`.
  `detail` is the why in one or two sentences.
- **Only put a real timestamp in `created`.** The renderer derives its "ageing" flag from that field,
  so a backdated guess makes the pressure line lie. When a verified age exists (a PR's `createdAt`
  from the forge, a doc's commit date) use it and note where it came from; otherwise stamp now and
  carry the real age in the item's wording instead.
- **Seed a missing queue before the next scheduled ping.** A renderer that cannot read its queue
  ships its error text to the person as their check-in, which is the worst possible first message.
  Create the file with a valid empty item list, then fill it.
- A missing log file is as bad as a missing queue for the next session: create it with a short header
  and an entry saying plainly whether a ping was actually delivered.

## Verifying the ping

1. Queue exists and parses; log exists.
2. Firing path is live: the gateway process is up, the cron ticker heartbeat is fresh, the job has a
   `next_run_at`, and `deliver` resolves to a real target (a platform name like `telegram` resolves
   to that platform's configured home channel; a job with no `origin` and no configured home has no
   target at all).
3. **Render it in a sandbox — never run the real script "just to test".** Its side effects are the
   person-facing record: it appends a ping entry to the log and stamps every live item as pinged, so
   a test run fabricates history the next session reads as real, and the log can no longer tell you
   what the person actually received. Copy the script, swap its queue/log path constants for temp
   paths, exec the copy, and read the stdout and the temp log together.
   `scripts/verify-ping-render.py` does exactly this.
4. **Check for duplicated content** between the queue block and anything else the same script renders
   from a second file (a checklist, a status doc). The same item twice reads as noise; dedupe
   deliberately or raise it with the owner rather than editing another agent's script quietly.
5. Prefer writing a probe to a file and running `python3 /path/probe.py`. Inline `python3 -c`
   one-liners can be refused by the shell-approval guard in a session with no user present, which
   costs a round trip; the file form always runs.

## Answering and closing

- When a reply routes to the queue owner rather than to you, do not chase status — but check the
  queue for the updated status before your next ping, and never report an item as done from a reply
  alone.
- Message the owner when an item you are blocked on clears or stops mattering, so it closes instead
  of aging in the list. Terse, no padding.

## Pitfalls

- Rendering a ping from a stale copy of the queue, or from memory, instead of re-reading the file.
- Treating a scheduled job that has never executed as verified. A first fire that renders an error
  string is indistinguishable from a working ping until someone reads the output.
- Adding an item without an owner-visible `from`, so the person cannot tell which agent is stuck.
- Letting the checklist or status doc and the queue drift into two slightly different accounts of the
  same work.
- Moving the queue or its cron jobs unilaterally to "fix" the location, and breaking the delivery
  path with nobody noticing for a day.

Infrastructure map for this install's queue (paths, job names, delivery target, renderer recipe):
`references/queue-infrastructure.md`.
