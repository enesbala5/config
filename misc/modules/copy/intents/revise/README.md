# Intent: revise

Owns editing, polishing, QA and content refresh of existing copy. Trigger: the
request changes copy that already exists — as opposed to write (new copy from
scratch), social, longform, or the read-only verify intent.

## Read first

- `<config>/misc/skills/copy/SKILL.md` — router (auto-loaded); confirms this intent.
- `<config>/misc/modules/copy/AGENTS.md` — hard gates, read-chain, records path.
- `<config>/misc/modules/copy/rules/README.md` — rules index.
- `<config>/misc/modules/copy/rules/editing/README.md` — this intent's rule set index.

Load individual rule files from `Rules applied` as each step needs them; do not
open a whole guide bucket or a sibling intent.

## Sequence

1. Classify the request: if new copy from scratch is needed, stop and hand off
   to write; otherwise pin down the author's core message and voice to preserve.
2. For stale published content, decide refresh vs rewrite; if refreshing, run
   the full set of refresh dimensions before calling it done.
3. Run focused single-dimension passes. In each pass, mark all problems before
   applying fixes, then confirm each fix keeps the original intent.
4. After each pass, re-verify every earlier pass; repeat until a full pass finds
   nothing new.
5. Sweep the draft for the final quality check and clear machine-signal
   transitions before it leaves revise.
6. In collaborative edits, present each finding with its reason and a specific
   proposed fix, then let the author make the final call.
7. For high-stakes copy, run the persona scoring gate and revise the weakest
   areas until the thresholds are met.
8. Write drafts, decisions and reviews to `<repo>/misc/copy/`, then hand off or
   mark done.

## Gates

- The author's core message and voice are identified and preserved, and each
  change has a clear reason before it is applied.
- High-stakes copy has cleared the persona gate; in collaborative edits the
  author has approved the change before it is applied.
- A full pass finds nothing new, and the final quality sweep is clean, before
  the draft is marked done.

## Rules applied

- `<config>/misc/modules/copy/rules/editing/preserve-core-message-and-voice.md`
- `<config>/misc/modules/copy/rules/editing/hand-off-new-copy-to-write.md`
- `<config>/misc/modules/copy/rules/editing/focused-dimension-passes.md`
- `<config>/misc/modules/copy/rules/editing/back-check-prior-passes.md`
- `<config>/misc/modules/copy/rules/editing/draft-quality-sweep-before-handoff.md`
- `<config>/misc/modules/copy/rules/editing/no-ai-tell-transitions.md`
- `<config>/misc/modules/copy/rules/editing/high-stakes-panel-gate.md`
- `<config>/misc/modules/copy/rules/editing/refresh-vs-rewrite-decision.md`
- `<config>/misc/modules/copy/rules/editing/refresh-covers-all-dimensions.md`
- `<config>/misc/modules/copy/rules/editing/collaborative-edit-author-decides.md`

Evidence for these rules lives in the `editing` bucket of
`<config>/misc/guides/copy/`; no lesson text is repeated here.

## Handoff

- On success → verify intent for a read-only check, otherwise done.
- On failure or out of scope → write intent when new copy is needed; back to
  the author for the final call on collaborative edits.

## Never

- Rewrite from scratch or replace the author's message under the guise of editing.
- Apply fixes inside a marking pass, or skip the back-check of earlier passes.
- Deliver copy that still has machine-signal transitions or has not passed the
  final quality sweep.
- Open a sibling intent or read a whole lesson bucket for a revise task.
