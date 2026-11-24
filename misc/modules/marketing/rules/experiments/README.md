# Experiment rules

What must be true for a test to produce a usable decision.

## Write the hypothesis before the variant

**Must be true:** The hypothesis states the change, the expected effect and the
reason before a variant is designed.

Evidence: `<config>/misc/guides/marketing/experiments/write-the-hypothesis-before-the-variant.md`

## Change one variable and make it bold enough to detect

**Must be true:** A test changes one variable, and the change is large enough to
produce a detectable effect.

Evidence: `<config>/misc/guides/marketing/experiments/change-one-variable-per-test.md`, `<config>/misc/guides/marketing/experiments/make-the-change-bold-enough-to-detect.md`

## Pre-commit sample, duration and stopping rule

**Must be true:** Sample size is sized from baseline and the smallest effect worth
acting on; duration is fixed in whole weeks and capped; the test does not stop on
an early lead.

Evidence: `<config>/misc/guides/marketing/experiments/size-the-test-from-baseline-and-mde.md`, `<config>/misc/guides/marketing/experiments/pre-commit-sample-and-do-not-stop-early.md`, `<config>/misc/guides/marketing/experiments/run-tests-in-whole-weeks-and-cap-them.md`

## Freeze the test and pre-register segments

**Must be true:** No changes are made while a test runs, and segments are declared
before results are sliced.

Evidence: `<config>/misc/guides/marketing/experiments/freeze-the-test-while-it-runs.md`, `<config>/misc/guides/marketing/mistakes/pre-register-segments-before-slicing.md`

## Give every test three metric tiers

**Must be true:** Each test names a primary metric, secondary metrics and a
guardrail metric.

Evidence: `<config>/misc/guides/marketing/experiments/give-every-test-three-metric-tiers.md`

## Pick one North Star metric

**Must be true:** One North Star metric aligns the programme; other metrics are
supporting or guardrails.

Evidence: `<config>/misc/guides/marketing/experiments/pick-one-north-star-metric.md`

## Diagnose the bottleneck before optimising

**Must be true:** The single constraint is identified first; reach volume is
prescribed only when reach is that constraint.

Evidence: `<config>/misc/guides/marketing/experiments/fix-the-bottleneck-before-optimising.md`, `<config>/misc/guides/marketing/experiments/volume-before-optimization.md`

## Run a prioritised, fixed-cadence programme

**Must be true:** The backlog is scored (ICE) and re-scored, tests run on a fixed
cadence, velocity and win rate are tracked, and winners become reusable patterns.

Evidence: `<config>/misc/guides/marketing/experiments/prioritise-the-backlog-with-ice.md`, `<config>/misc/guides/marketing/experiments/run-a-fixed-experiment-cadence.md`, `<config>/misc/guides/marketing/experiments/track-velocity-and-win-rate.md`, `<config>/misc/guides/marketing/experiments/promote-winners-to-a-pattern-playbook.md`

## Change the question when traffic cannot power the test

**Must be true:** When traffic cannot support the test, the question or complexity is
changed instead of running an underpowered test.

Evidence: `<config>/misc/guides/marketing/experiments/change-the-question-when-traffic-cannot-power-it.md`, `<config>/misc/guides/marketing/experiments/match-test-complexity-to-traffic.md`

## Judge underperformers on current evidence and test incentives

**Must be true:** Underperformers are cut on current evidence, not past spend, and
incentives are tested for backfire before scaling.

Evidence: `<config>/misc/guides/marketing/mistakes/kill-underperformers-on-current-evidence.md`, `<config>/misc/guides/marketing/mistakes/test-incentives-for-backfire.md`
