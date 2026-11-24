# Call the test with a fixed six-question checklist

**Feeds stage:** verify

Before declaring a result, answer in order:

1. Was the pre-calculated sample reached? If not, the result is preliminary.
2. Is the effect statistically significant — does the confidence interval
   exclude zero?
3. Is the effect at least the MDE and worth implementing? Statistical
   significance is not practical significance.
4. Do the secondary metrics support the story?
5. Are the guardrails clean?
6. Do the pre-planned segments differ in a way that changes the decision?

Then decide by rule: significant winner, ship it; significant loser, keep control
and learn why; no difference, you need more traffic or a bolder test; mixed
signals, dig into segments or run a follow-up. Inconclusive is not a soft win.
