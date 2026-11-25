# Rules: verification

Checks before accepting a test, claim or change. Loaded by `verify` only.

- **Pre-committed, single-variable tests.** Commit the hypothesis before the
  test, change one variable, and wait for adequate sample and significance before
  calling a result.
  Evidence: `<config>/misc/guides/conversion/experiments/ab-test-one-variable-at-a-time.md`
- **Metric tiers.** Define a primary conversion metric and guardrail metrics, and
  measure the full funnel rather than a single click.
  Evidence: `<config>/misc/guides/conversion/experiments/track-paywall-funnel-metrics.md`
  Evidence: `<config>/misc/guides/conversion/experiments/track-email-benchmarks-by-metric.md`
- **Classify recommendations.** Separate quick wins from hypotheses worth
  testing; never treat a hypothesis as a settled fix.
  Evidence: `<config>/misc/guides/conversion/experiments/separate-quick-wins-from-tests.md`
- **Genuine urgency only.** Do not manufacture urgency or scarcity to lift
  conversion.
  Evidence: `<config>/misc/guides/conversion/mistakes/only-test-urgency-if-genuine.md`
- **No paywall dark patterns.** Be honest about what is paid, what happens on
  decline and what the user agrees to; no hidden close, confusing plans or
  guilt-trip copy.
  Evidence: `<config>/misc/guides/conversion/mistakes/avoid-paywall-dark-patterns.md`
- **No trapping.** Every gated step has a skip or exit, and dismissed guidance
  does not return for returning users.
  Evidence: `<config>/misc/guides/conversion/mistakes/avoid-trapping-users-in-onboarding.md`
