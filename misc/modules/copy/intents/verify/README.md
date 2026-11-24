# Intent: verify

Read-only QA over any copy artifact — owns checks that report findings, never fixes; triggers when asked to check, review or QA existing copy rather than write, revise, social or longform it.

## Read first

`<config>/misc/modules/copy/README.md` is the module index; `<config>/misc/modules/copy/AGENTS.md` owns the hard gates. Then load, in order: `<config>/misc/modules/copy/rules/README.md`, `<config>/misc/modules/copy/rules/cross-cutting/README.md`, and the two rule files named under Rules applied. Artifacts and findings live in `<repo>/misc/copy/`. Do not load a whole bucket or a sibling intent.

## Sequence

1. Identify the artifact, its surface (page copy, editing, X, comment reply, technical post) and its location under `<repo>/misc/copy/`; if either is unclear, ask instead of guessing.
2. Run the no-fabrication check from the cross-cutting rule set over the whole artifact.
3. Run the voice-sourcing check: confirm the project's product-marketing context was read, or that a technical post takes the author's published-post voice.
4. Run the owning surface's pre-ship checks by name — never restate or re-derive them here:
   - X batch → `<guide>/social/x-format-bans.md`, `<guide>/social/trace-claims-with-a-from-line.md`, `<guide>/social/self-check-the-batch-before-shipping.md`
   - editing / revise → `<guide>/editing/quick-quality-check-pass.md`, `<guide>/editing/seven-focused-sweeps.md`
   - technical post → `<guide>/longform/never-use-the-blog-post-trope-list.md`
   - page or messaging copy → `<guide>/page-copy/require-five-inputs-before-page-copy.md`
5. Report each finding as file:line + failed check + owning intent, then stop. No artifact is changed.

## Gates

- The artifact and its surface are identifiable; otherwise ask, do not infer.
- No edits are made, so no approval is required. The finding report is the deliverable.

## Rules applied

- `<config>/misc/modules/copy/rules/cross-cutting/claims-must-trace-to-a-source.md` — evidence bucket: cross-cutting.
- `<config>/misc/modules/copy/rules/cross-cutting/voice-from-product-marketing-context.md` — evidence bucket: cross-cutting.
- Surface checks stay in their owning rule sets; this intent names and runs them, it does not duplicate them.

## Handoff

- On success (report delivered, nothing changed) → done.
- On failure or out of scope → hand fixes back to the owning intent: `write`, `revise`, `social` or `longform`.

## Never

- Edit an artifact in this read-only intent.
- Restate or duplicate a surface rule here; run it and report only.
- Fabricate a source while checking for fabricated sources.
- Open a sibling intent or read a whole lesson bucket for this task.
