# Intent: social

Owns X post batches and comment replies. Trigger: any request for X post options, a
target-account batch, or "respond to this" on a comment, post or thread; siblings own
page copy (`write`), revisions (`revise`), technical posts (`longform`) and read-only
review (`verify`).

## Read first

`<config>/misc/modules/copy/AGENTS.md` owns the hard gates. Then, in read order:

1. `<config>/misc/modules/copy/rules/README.md` — rule conventions.
2. `<config>/misc/modules/copy/rules/social/README.md` — this set's index; load only the rule files named under "Rules applied" below.
3. `<config>/misc/modules/copy/references/README.md` — index of the pinned contracts. Read the contract the task needs: target-voice registers and banned lists, the voice-source cache, the delivered-angles ledger and its lookback window, recent material, and the batch or reply output format. Do not load the whole directory.

## Sequence

1. Resolve the request to one path, X batch or comment reply. If neither, hand back to the router.
2. Load the chain above and the pinned contracts for that path. Read voice and messaging sources fresh through the cached reader; hold the target registers and banned lists in hand. Never draft from memory.
3. X batch path:
   1. Read recent material and the delivered-angles ledger; drop every angle inside the pinned lookback window.
   2. Pick build options with a real story; decide whether a topical option qualifies against a named source, otherwise use a build-in-public option.
   3. Draft two options per target, one register per brand post, each with a `from:` line and a measured length.
   4. Run the mechanical dash and URL check, the self-check and the stranger test; record delivered options in the single ledger.
4. Comment reply path:
   1. Read the actual thread, verify it is recent, separate speakers, and declare the target type in one line; request text for unreadable material.
   2. Write the deciding analysis down, read the register used in that thread, then draft one recommended reply in house shape and one alternative; keep links and pitches out.
   3. Run the dash and URL check, the anti-AI voice check and the ad stranger test; fix every flag.
5. Hand the copy-paste-ready drafts to the human. This intent has no publishing step.

## Gates

- Voice sources and target registers are loaded fresh before the first draft.
- The delivered-angles ledger has been consulted; no angle inside the lookback window is repeated.
- Every concrete claim traces to material actually read or to a named source.
- Mechanical checks return empty, and character counts are measured rather than estimated.
- Done means drafts meet the pinned output format and are handed over; the human reviews and posts manually.

## Rules applied

- `<config>/misc/modules/copy/rules/social/separate-personal-and-brand-registers.md`
- `<config>/misc/modules/copy/rules/social/one-brand-register-per-post.md`
- `<config>/misc/modules/copy/rules/social/every-option-carries-a-from-line.md`
- `<config>/misc/modules/copy/rules/social/topical-claims-need-named-source.md`
- `<config>/misc/modules/copy/rules/social/no-fabricated-topical-option.md`
- `<config>/misc/modules/copy/rules/social/mechanical-dash-and-link-check.md`
- `<config>/misc/modules/copy/rules/social/no-banned-engagement-phrases.md`
- `<config>/misc/modules/copy/rules/social/post-length-limit.md`
- `<config>/misc/modules/copy/rules/social/at-most-one-real-ask.md`
- `<config>/misc/modules/copy/rules/social/copy-paste-ready-output.md`
- `<config>/misc/modules/copy/rules/social/drop-delivered-angles.md`
- `<config>/misc/modules/copy/rules/social/ledger-is-the-only-archive.md`
- `<config>/misc/modules/copy/rules/social/commit-message-is-not-an-angle.md`
- `<config>/misc/modules/copy/rules/social/two-options-per-target.md`
- `<config>/misc/modules/copy/rules/social/build-option-needs-a-real-story.md`
- `<config>/misc/modules/copy/rules/social/read-voice-sources-through-cache.md`
- `<config>/misc/modules/copy/rules/social/stranger-test-before-delivery.md`
- `<config>/misc/modules/copy/rules/social/declare-reply-target-type.md`
- `<config>/misc/modules/copy/rules/social/read-thread-before-reply.md`
- `<config>/misc/modules/copy/rules/social/request-unreadable-material.md`
- `<config>/misc/modules/copy/rules/social/answer-person-before-angle.md`
- `<config>/misc/modules/copy/rules/social/recommended-reply-house-shape.md`
- `<config>/misc/modules/copy/rules/social/post-launch-offer-wording-updated.md`
- `<config>/misc/modules/copy/rules/social/no-links-or-pitches-in-replies.md`
- `<config>/misc/modules/copy/rules/social/match-thread-register.md`
- `<config>/misc/modules/copy/rules/social/anti-ai-check-on-replies.md`
- `<config>/misc/modules/copy/rules/social/no-reused-openers-within-thread.md`
- `<config>/misc/modules/copy/rules/social/drafts-only-never-publish.md`

## Handoff

- On success → done; drafts go to the human, who posts or schedules manually.
- On failure or out of scope → back to `<config>/misc/skills/copy/SKILL.md` for routing to a sibling intent; when material is unreadable, ask the human for the text.

## Never

- Never post, schedule, publish or scrape; no platform APIs from this intent.
- Never invent a topical item, metric, client, claim or source.
- Never blend personal and brand registers, repeat a delivered angle or opener, or carry a link or pitch into a reply.
- Never keep separate batch files, reports or scratch documents; the ledger is the only archive.
- Never load a whole lesson bucket or open a sibling intent for this task.
