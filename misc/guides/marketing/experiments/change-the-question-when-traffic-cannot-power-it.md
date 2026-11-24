# When traffic cannot power the test, change the question

**Feeds stage:** verify

If the duration calculation lands beyond about 60 days, do not run a test that
cannot detect the effect you care about. Pick a different move:

- raise the MDE and accept that only large lifts are detectable;
- test only the single most promising variant;
- move upstream in the funnel where traffic is higher;
- pool several similar pages into one test;
- decide from qualitative evidence and explicitly do not test.

Lowering confidence to 90% is available but risky: document the choice and treat
the result as weaker evidence. The failure mode is a two-month test whose
confidence interval is wider than the business decision it was meant to inform.
