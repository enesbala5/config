# Pre-register segments; do not cherry-pick a winner after the fact

**Feeds stage:** verify

Segment analysis is for explaining a result, not for rescuing a flat one. Decide
before launch which segments you will inspect — mobile versus desktop, new versus
returning, traffic source — and if a segment decision matters, size the test for
the smallest segment you plan to analyse.

A test with no overall effect but one glowing subgroup out of six is usually
noise. Reporting "it worked on mobile" after checking every cut is the analysis
equivalent of peeking.

Counterexample: a flat headline test reported as a mobile win, then rolled out
everywhere on the strength of a subgroup that was never powered to decide
anything.
