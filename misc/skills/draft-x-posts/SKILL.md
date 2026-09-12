---
name: draft-x-posts
description: Draft a batch of ready-to-post X options for a target voice.
version: 0.1.0
author: Enes Bala (enesbala5), Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [social-media, x, drafts, personal-brand, coverlttr, cron]
    related_skills: [comment-response, coverlttr-x-organic-replies, brand-voice]
---

# Draft X posts

Hand Enes ready-to-post X options built from his own recent work plus one topical angle, aimed at a named account. He posts manually. Nothing here posts, schedules, or scrapes.

## When to use

- The scheduled batch (11:00, 14:00, 17:00, 20:00 Europe/Tirane) or any ask like "what should I post", "post ideas for X", "draft a post about X".
- One target on request, or the full batch of two targets.
- Not for replying to someone else's post (that is `comment-response`) and not for Reddit (that is `coverlttr-x-organic-replies`).

## Target = who we are speaking as

| Target | Account | Voice reference |
| --- | --- | --- |
| `personal` | @enesbala_ | [references/personal.md](references/personal.md) |
| `coverlttr` | @coverlttr | [references/coverlttr.md](references/coverlttr.md) |

Read the target reference before drafting. The two never blend: a Coverlttr idea on the personal account is a story about building it, on the brand account it is a product claim. Adding a target means adding one reference file and one row here.

## Voice sources are cached, never re-cloned

Voice files live in his GitHub repos. Read them through the cached reader: never a fresh clone per run, never a per-file `gh api` call.

```bash
bash scripts/repo-file.sh enesbala5/portfolio main misc/TONE.md misc/PROFILE.md
bash scripts/repo-file.sh enesbala5/coverlttr dev docs/marketing/messaging.md docs/marketing/brand-voices/precise-advocate.md
```

Clone once, pull at most once per TTL, read from disk, keep working if the pull fails. The full contract is in [references/repo-cache.md](references/repo-cache.md). `comment-response` calls the same script as `../draft-x-posts/scripts/repo-file.sh`, so one cache and one pull serve both skills.

## Material

```bash
bash scripts/recent-work.sh 36
```

Prints commits and merged PRs across `portfolio`, `coverlttr`, `merre`, `lune`, `config` from the last 36 hours, newest first, and says so explicitly when a repo has nothing. That output is the build-in-public pool: pick the change with a real story behind it (a decision, a bug, a trade-off, a thing he learned), not the change with the biggest diff.

Topic material comes from `web_search`, at most two queries per batch, in the lanes he actually has standing in: cover letters and hiring, AI tooling for developers, Albanian ecommerce and marketplaces, NixOS and self-hosting. A topical option is only valid when the item is real and recent and he has a non-obvious take. If nothing qualifies, ship a third build-in-public option instead and say so in one line.

## Batch composition

Four options: two for `personal`, two for `coverlttr`. Across the four: two built from his own recent work, one topical or reaction option, one free slot that goes to whichever signal is stronger that day (tie-break: his own work). Never four ideas from one commit.

Before drafting, read the last 200 lines of the ledger and drop any commit, PR, or angle already delivered in the previous 14 days. A repeated angle is worse than a thin batch.

## Hard rules

1. No em dashes or en dashes. Commas, or restructure.
2. No URLs in the post text, for either account. The link lives in the bio; a launch post can note that the link goes in the first reply.
3. One post per option: 280 characters or fewer. When the story genuinely needs more, a numbered thread of two to three posts, each 280 or fewer. Never a wall of text.
4. No hashtags. No "Excited to share", no fake curiosity hooks, no growth-hacker cadence, no engagement bait.
5. No invented metrics, clients, awards, or dates. Every concrete claim traces to TONE.md, PROFILE.md, the Coverlttr docs, or a commit that is actually in the material.
6. No overclaims: never "ATS-proof", never guaranteed interviews, never celebrating mass applying.
7. One ask maximum per option, and only when it is real (feedback on a screen, a question he wants answered).
8. Reread the target reference's banned list before the self-check. The personal and brand registers have different bans.

## Output contract

Telegram message, nothing before it and nothing after it:

```
X posts, 4 options

1. personal, @enesbala_
from: portfolio 3441294, personal brand docs
<draft>
(241 chars)

2. personal, @enesbala_
from: topical, hiring news
<draft>
(198 chars)

3. coverlttr, @coverlttr
voice: Precise Advocate, from: messaging.md
<draft>
(263 chars)

4. coverlttr, @coverlttr
voice: Application Operator, from: coverlttr commits
<draft>
(221 chars)
```

The draft is copy-paste ready: plain text, no quotes around it, no markdown decoration, no code fence. One `from:` line per option naming the source, kept to a few words. No preamble, no process narration, no offer to do more.

## Procedure

1. Read the target references for the accounts in the batch. Done when both registers are loaded and the banned lists are in hand.
2. Fetch the voice sources through `scripts/repo-file.sh` (one call per repo, paths listed in the reference). Done when TONE.md and the Coverlttr docs are in context.
3. Run `scripts/recent-work.sh 36`. Done when there is a shortlist of candidate changes with a story.
4. Read the ledger tail and drop repeats. Done when no candidate collides with the last 14 days.
5. Search for the topical option, or decide to skip it. Done when the item is dated within the last week and the take is his, not a summary.
6. Draft the four options against the target references and the hard rules.
7. Self-check, then append to the ledger.

## Self-check

- Dashes and links, mechanically:
  ```bash
  grep -nP '[\x{2013}\x{2014}]|https?://|\bwww\.' drafts.txt
  ```
  Empty output is the pass. Any hit is a fail, fix and re-run.
- Every claim traceable to a file just read or a commit in the material output.
- Personal options sound like Enes, not a brand; brand options use one register, not a blend of three.
- Both accounts represented, four options, each with its `from:` line.
- Would a stranger read the brand options as an ad, or the personal ones as a growth thread? Rewrite if so.
- Ledger appended at `~/.hermes/x-posts/delivered.jsonl`, one object per option:
  `{"id": "<repo>:<sha|slug>", "target": "personal", "voice": "-", "angle": "<one line>", "text": "<draft>", "at": "<ISO8601>"}`

## Pitfalls

- Drafting from memory of the voice files. They change, and the cached reader exists so there is no excuse.
- Reposting the same commit under a new opener. The ledger is keyed on ids and angles for exactly this reason.
- Treating a commit message as a story. `Fix OG image filename` is not a post; the reason behind it can be.
- Brand copy on the personal account. That is the fastest way to make his feed look like a product feed.
- Inventing the topical option. A weak batch of three honest options beats a fabricated news reaction.
- Padding to hit the register he uses on big recaps. Those came from events that actually happened; if the material is thin, write the short post.
- Em dashes in the batch message itself. The grep covers the drafts; the surrounding message is still his copy.
- A pull on every run. `repo-file.sh` owns the TTL; do not call `gh api` or `git clone` in parallel with it.

## Verification

1. Four options, two per target, every draft under the character rule and free of dashes and URLs.
2. `grep` self-check returns nothing.
3. Every `from:` line names something that appears in the material output.
4. Ledger has four new lines with today's timestamp.
