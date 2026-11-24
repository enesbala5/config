# Match test complexity to available traffic

**Feeds stage:** verify

Choose the test type from traffic, not ambition. A/B (two variants) is the
default. A/B/n multiplies the sample needed — roughly 1.5× for three variants and
2× for four — because every added arm creates more comparisons and more chances
of a false positive. Multivariate tests multiply combinations outright: two
headlines × two images × two CTAs is eight cells.

Correct for multiple comparisons or use a tool that does, and prefer fewer arms
where traffic is thin. Counterexample: splitting a modest audience four ways to
test four button colours, producing four inconclusive results. Sequential A/B
tests answer the same questions with less traffic.
