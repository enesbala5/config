# Intent: plan

Owns turning an approved position into an offer, channel plan, launch sequence,
campaign roles and test design. Trigger: "build the offer / where should we launch /
what is the plan" after positioning is approved.

## Read first

`<config>/misc/modules/marketing/AGENTS.md` owns the hard gates. Then read, in
order: the approved positioning brief, then the rule sets this task needs —
`<config>/misc/modules/marketing/rules/offers/README.md`,
`<config>/misc/modules/marketing/rules/channels/README.md`,
`<config>/misc/modules/marketing/rules/launch/README.md`,
`<config>/misc/modules/marketing/rules/experiments/README.md` — and only the named
guide buckets. Do not load a whole bucket or a sibling intent.

## Sequence

1. Audit the offer against the value equation and the six components; fix the
   weakest lever, one at a time.
2. Choose one or two channels by audience signal, budget and time horizon; route
   each to owned capture.
3. Sequence the launch: clear the pre-launch gate, give each deliverable one job,
   plan the post-launch adoption phase.
4. For each claim or tactic worth testing, write the hypothesis, sample, duration
   and metric tiers.
5. Record the plan, marking what needs human approval.

## Gates

- Offer, pricing and claims are approved by the human.
- The channel set is deliberate and bounded; no channel sprawl.
- Tests are pre-committed; no early stopping.
- No copy or visual asset is produced here.

## Rules applied

`<config>/misc/modules/marketing/rules/offers/README.md`,
`<config>/misc/modules/marketing/rules/channels/README.md`,
`<config>/misc/modules/marketing/rules/launch/README.md`,
`<config>/misc/modules/marketing/rules/experiments/README.md` — with evidence in
the matching guide buckets.

## Handoff

- On success → **handoff** to package the brief for `copy` or `design`.
- Test validity or results → **verify**.
- On failure or out of scope → **position** or **research** for the missing input.

## Never

- Write copy or visuals, publish or schedule, or launch without the pre-launch gate.
