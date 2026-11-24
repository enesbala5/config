# Give every test a primary, secondary and guardrail metric

**Feeds stage:** verify

Choose one primary metric tied directly to the hypothesis; it is the only number
used to call the test. Add secondary metrics that explain why or how the change
worked, and guardrail metrics that must not get worse.

Pricing-page example: primary is plan selection rate; secondary are time on page
and plan distribution; guardrails are support tickets and refund rate. A longer
signup form might raise lead quality (secondary) while the completion rate
(primary) falls — the tiers make that trade-off visible instead of hiding it.

Guardrails are a stop condition, not decoration: if one is significantly
negative, end the test regardless of the primary metric. Counterexample:
declaring victory on clicks when the business is paid on plan selection.
