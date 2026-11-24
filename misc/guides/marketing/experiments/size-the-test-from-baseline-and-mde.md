# Size the test from baseline and the smallest effect worth acting on

**Feeds stage:** verify

Calculate sample size before launch from four inputs: the page's baseline
conversion rate, the minimum detectable effect (MDE) worth acting on, 95%
confidence, and 80% power. Use the rate for that specific page and metric, never
a site-wide average.

Indicative sample per variant: at a 3% baseline, detecting a 10% lift needs about
120,000 visitors, a 20% lift about 31,000, a 50% lift about 5,200. At a 1%
baseline, a 10% lift needs about 380,000. Smaller effects cost disproportionately
more traffic.

Set the MDE from business value and implementation cost: what is the smallest
lift that would justify shipping the change? An underpowered test cannot detect a
realistic effect, so it produces a false negative with confidence.
