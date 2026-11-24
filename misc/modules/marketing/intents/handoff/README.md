# Intent: handoff

Owns packaging an approved strategy artifact for `copy` or `design`, and enforcing
the boundary between strategy and execution. Trigger: "hand this to copy / brief the
designer / is this ready to produce".

The `design` module consumes this brief together with the `copy` output: strategy
supplies the aims, angle and claims; `copy` supplies the words; `design` supplies
the visual and layout execution.

## Read first

`<config>/misc/modules/marketing/AGENTS.md` owns the hard gates. Then read, in
order: `<config>/misc/modules/marketing/rules/handoffs/README.md` and the guide
index `<config>/misc/guides/marketing/handoffs/README.md`. Do not load a whole
bucket or a sibling intent.

## Sequence

1. Confirm the approved positioning, angle, tone, offer and claims.
2. Assemble the receiving module's brief: objective, audience, stage of awareness,
   message, evidence or quote bank, claims/anti-claims, constraints, success metric.
3. State what the receiving module owns and what strategy will not decide.
4. Record the handoff in `<repo>/misc/marketing/` with a stable kebab-case slug.
5. Check cross-deliverable consistency before release.

## Gates

- The human has approved the positioning brief and tone.
- The brief is complete; no open strategic question is left to the receiving module.
- No copy or visual work is done in this intent.

## Rules applied

`<config>/misc/modules/marketing/rules/handoffs/README.md` (evidence in
`<config>/misc/guides/marketing/handoffs/`), plus the boundary limits in
`<config>/misc/modules/marketing/rules/mistakes/README.md`.

## Handoff

- On success → the `copy` module for content, or the `design` module for visual and
  layout execution; or done.
- On failure or out of scope → the owning intent (research, position or plan); do
  not send an incomplete brief.

## Never

- Draft copy, choose layout/colour/type, or send a brief that still contains an open
  strategy decision.
