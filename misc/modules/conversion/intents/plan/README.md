# Intent: plan

Owns lifecycle email sequence design — goal, audience, cadence, triggers,
structure and measurement — and any design decision that follows an audit of
activation or monetization. Trigger: "plan / design an email sequence", or "turn
this finding into a design decision".

## Read first

`<config>/misc/modules/conversion/AGENTS.md` owns the hard gates. Then read
`<config>/misc/modules/conversion/rules/README.md` and
`<config>/misc/modules/conversion/rules/design/README.md`; also read
`<config>/misc/modules/conversion/rules/diagnosis/README.md` when an
activation/monetization design decision needs a diagnosis. Open only named
lessons in the `lifecycle-email/` bucket, plus the `activation/` or
`monetization/` lessons the design decision needs.

## Sequence

1. **Gather context.** Establish the sequence goal, audience and stage, sales
   cycle, existing in-app flow and the actions users have or have not taken.
2. **Design the sequence.** One job and one CTA per email; a value-to-ask arc;
   relevance over volume; triggered over time-based sends; segment by behavior,
   stage and profile; set length, cadence, subject and preview text.
3. **Coordinate with the product.** Make email reinforce the in-app flow rather
   than repeat it; personalize on real user actions; define each sequence's goal
   and metrics.
4. **Record and present.** Write the plan under `<repo>/misc/conversion/` and
   present it for approval; hand copy execution to `copy`.

## Gates

- All eight hard gates in `<config>/misc/modules/conversion/AGENTS.md` apply;
  domain checks live in `rules/design/README.md` (and `rules/diagnosis/README.md`
  for activation/monetization decisions).
- Approve the sequence plan before any send or copy execution is commissioned.

## Rules applied

`<config>/misc/modules/conversion/rules/design/README.md` (`lifecycle-email/`,
plus `activation/` and `monetization/` where a design decision requires it). No
lesson text is copied here.

## Handoff

- On success → `verify` if the sequence needs a test; otherwise done.
- Final copy → `copy` module.
- A gap in the underlying diagnosis → back to `audit`.

## Never

- Duplicate the in-app onboarding sequence in email.
- Schedule, publish or send, or produce final copy in this intent.
