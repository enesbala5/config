# Intent: audit

Owns requests to diagnose and recommend fixes for a page, form, onboarding or
paywall/upgrade surface. Trigger: "audit / improve this conversion surface" —
as opposed to designing an email sequence (`plan`) or checking a test or claim
(`verify`).

## Read first

`<config>/misc/modules/conversion/AGENTS.md` owns the hard gates. Then read
`<config>/misc/modules/conversion/rules/README.md`, followed by
`<config>/misc/modules/conversion/rules/diagnosis/README.md` and
`<config>/misc/modules/conversion/rules/design/README.md`. Open only the named
lesson files in the `page-conversion/`, `activation/` and `monetization/` buckets
— never a whole bucket and never a sibling intent.

## Sequence

1. **Gather context.** Check existing marketing/product-marketing docs, then
   confirm the surface type, primary conversion goal, traffic source, current and
   target rate, the funnel after the surface, prior research and prior attempts.
2. **Diagnose.** Map value-proposition clarity, the primary action, friction and
   objections; find the largest drop-off. Record each issue as finding + impact +
   evidence + priority.
3. **Recommend.** Rank changes as quick wins, high-impact changes, test ideas and
   copy alternatives. Keep one primary action per surface and place any upgrade
   ask only after value. Hand test ideas to `verify`.
4. **Record and present.** Write findings and ranked recommendations under
   `<repo>/misc/conversion/` and present them for approval.

## Gates

- All eight hard gates in `<config>/misc/modules/conversion/AGENTS.md` apply;
  domain checks live in the two rule sets named above.
- Present the diagnosis and ranked recommendations for user approval before any
  recommendation is treated as decided.

## Rules applied

`<config>/misc/modules/conversion/rules/diagnosis/README.md` (buckets
`page-conversion/`, `activation/`, `monetization/`) and
`<config>/misc/modules/conversion/rules/design/README.md` (same buckets). No
lesson text is copied here.

## Handoff

- On success → `plan` if an email sequence is needed; `verify` for any test
  idea; otherwise done.
- Copy or visual/layout direction → `copy` / `design` modules.
- Missing context or out of scope → back to the user.

## Never

- Prescribe a change without a finding, evidence, impact and priority.
- Write final copy or visual/layout direction, or publish, schedule or send.
