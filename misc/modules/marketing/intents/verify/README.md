# Intent: verify

Read-only audit of a strategy artifact, claim set, research brief, offer, plan, test
or launch against the gates. Trigger: "is this sound / check the claims / review the
plan / did the test hold". Never edits.

## Read first

`<config>/misc/modules/marketing/AGENTS.md` owns the hard gates. Then read, in
order: `<config>/misc/modules/marketing/rules/mistakes/README.md`,
`<config>/misc/modules/marketing/rules/experiments/README.md`, and the artifact
under review. Do not load a whole bucket or a sibling intent.

## Sequence

1. Check the evidence floor, segments and confidence labels.
2. Check claims/anti-claims, ethics and second-order effects.
3. Check test validity: hypothesis, one variable, sample/duration, metric tiers,
   pre-registration, early stopping.
4. Check the copy/design boundary and handoff completeness.
5. Report blocking and advisory findings with exact paths and the owning intent.

## Gates

- Read-only: no file is edited, merged or deleted.
- No approval is granted on the human's behalf.
- Findings name the owning intent and the evidence.

## Rules applied

`<config>/misc/modules/marketing/rules/mistakes/README.md`,
`<config>/misc/modules/marketing/rules/experiments/README.md`, and the set that owns
the artifact under review.

## Handoff

- Problems → the owning intent (**research**, **position**, **plan** or **handoff**)
  with the exact findings.
- No problems → done.

## Never

- Edit, merge or delete anything, publish, or present an advisory finding as a
  blocker without saying why.
