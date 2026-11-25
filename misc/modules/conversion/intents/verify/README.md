# Intent: verify

Owns read-only checking of experiments, claims and anti-patterns against the
evidence. Trigger: "is this test valid / is this claim or change acceptable" —
not diagnosing a surface (`audit`) or designing a sequence (`plan`).

## Read first

`<config>/misc/modules/conversion/AGENTS.md` owns the hard gates. Then read
`<config>/misc/modules/conversion/rules/README.md` and
`<config>/misc/modules/conversion/rules/verification/README.md`. Open only named
lessons in the `experiments/` and `mistakes/` buckets.

## Sequence

1. **Read the candidate.** Take the change, claim or test from
   `<repo>/misc/conversion/` (or from the request) without modifying it.
2. **Check test validity.** Confirm a pre-committed hypothesis, one variable, a
   primary metric plus guardrails, sufficient sample and significance, and a
   split between quick wins and hypotheses worth testing.
3. **Check ethical limits.** Reject manufactured urgency, paywall dark patterns,
   trapping and ignored dismissal.
4. **Emit a verdict.** Record a read-only verdict with reasons; hand any fix back
   to `audit` or `plan` with the specific lesson evidence.

## Gates

- All eight hard gates in `<config>/misc/modules/conversion/AGENTS.md` apply;
  domain checks live in `rules/verification/README.md`.
- This intent is read-only: nothing is edited, published, scheduled or sent.

## Rules applied

`<config>/misc/modules/conversion/rules/verification/README.md` (buckets
`experiments/` and `mistakes/`). No lesson text is copied here.

## Handoff

- On success → done (verdict recorded).
- Diagnosis or design fix needed → `audit` (surface) or `plan` (email).
- Redesign needed → back to `verify` once `audit`/`plan` supplies the fix.

## Never

- Edit a record, the guide, or the thing being verified.
- Publish, schedule or send, or write copy and layout direction.
