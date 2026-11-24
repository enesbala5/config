# Intent: longform

Owns technical how-to posts about a setup that already works — triggered by a request for a working write-up with real receipts, a git-derived storyline, and a HEAD walkthrough, not by web/marketing page copy (`write`), edits to existing copy (`revise`), X batches or replies (`social`), or a read-only check (`verify`).

## Read first

`<config>/misc/skills/copy/SKILL.md`
`<config>/misc/modules/copy/README.md`
`<config>/misc/modules/copy/AGENTS.md`
`<config>/misc/modules/copy/rules/README.md`
`<config>/misc/modules/copy/rules/longform/README.md`
`<config>/misc/guides/copy/README.md`
`<config>/misc/guides/copy/longform/README.md`
`<config>/misc/modules/copy/references/README.md` — portfolio destination and frontmatter contract

Load in this order, root first. Open a guide lesson only through the evidence
pointer on a rule when it must be checked; never read the whole lesson bucket or
a sibling intent. The portfolio destination is a contract declared in
`<config>/misc/modules/copy/references/`, never a hard-coded universal path.

## Sequence

1. Confirm the request is a working-setup write-up. Record the receipts — environment, problem, promised end state, real artifacts and versions, deliberate exclusions, attribution — under `<repo>/misc/copy/`; if receipts are short, write the skeleton and park the post rather than inventing values.
2. If a git path is referenced, resolve it from that path and mine its diffs for storyline beats before outlining; ask the user when history conflicts with their account instead of overriding it silently.
3. Write from current HEAD files with reader-specific placeholders, following the fixed skeleton, the voice profile calibrated on the author's published posts, and the frontmatter contract in `<config>/misc/modules/copy/references/`.
4. Check the rule set before finishing: fenced code with context above, callouts with a real job, a mechanism-list conclusion with the optional/required split, named limitations, and no generated image assets.
5. Hand off.

## Gates

- `<config>/misc/modules/copy/AGENTS.md` owns authority and approval; this intent does not redefine them.
- Receipts are complete, or the skeleton is parked, before walkthrough prose is written.
- A referenced repo is resolved and mined before outlining.
- The portfolio destination and its frontmatter contract are confirmed in `<config>/misc/modules/copy/references/`; the user approves `published` before the post goes live.
- Done means the rule set passes and records under `<repo>/misc/copy/` are updated.

## Rules applied

`<config>/misc/modules/copy/rules/longform/collect-real-receipts.md`
`<config>/misc/modules/copy/rules/longform/no-fabricated-setup.md`
`<config>/misc/modules/copy/rules/longform/mine-referenced-repo-before-outlining.md`
`<config>/misc/modules/copy/rules/longform/derive-storyline-from-diffs.md`
`<config>/misc/modules/copy/rules/longform/walkthrough-shows-head.md`
`<config>/misc/modules/copy/rules/longform/body-follows-fixed-skeleton.md`
`<config>/misc/modules/copy/rules/longform/introduction-opens-on-readers-setup.md`
`<config>/misc/modules/copy/rules/longform/walkthrough-step-shape.md`
`<config>/misc/modules/copy/rules/longform/name-limitations-in-callouts.md`
`<config>/misc/modules/copy/rules/longform/sharp-mechanisms-hedged-results.md`
`<config>/misc/modules/copy/rules/longform/conclusion-is-a-mechanism-list.md`
`<config>/misc/modules/copy/rules/longform/use-technical-how-to-register.md`
`<config>/misc/modules/copy/rules/longform/calibrate-on-authors-published-posts.md`
`<config>/misc/modules/copy/rules/longform/first-person-peer-voice.md`
`<config>/misc/modules/copy/rules/longform/no-question-openings.md`
`<config>/misc/modules/copy/rules/longform/no-blog-trope-filler.md`
`<config>/misc/modules/copy/rules/longform/callouts-have-a-job.md`
`<config>/misc/modules/copy/rules/longform/fence-code-with-context-above.md`
`<config>/misc/modules/copy/rules/longform/match-frontmatter-contract.md`
`<config>/misc/modules/copy/rules/longform/no-image-assets.md`

## Handoff

- On success → `<config>/misc/modules/copy/intents/verify/README.md` for a read-only check, then done.
- On failure or out of scope → router `<config>/misc/skills/copy/SKILL.md`: web/marketing copy to `write`, existing-copy edits to `revise`, X/replies to `social`.

## Never

- Never generate image assets for a post.
- Never fabricate a receipt, config, or walkthrough, or present git archaeology as the working setup.
- Never blend the marketing register into a technical post or open on a question.
- Never edit in the read-only `verify` intent.
