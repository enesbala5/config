# Freeze the test while it runs

**Feeds stage:** verify

Once a test is live, the experiment is fixed: do not edit the variants, do not
add traffic from new sources, and do not change targeting mid-flight. Each of
those silently creates a third condition and destroys attribution.

What you may do during the run: monitor for technical issues and tracking
breakage, check that the randomisation is producing comparable segments, and
document external events (a press mention, a holiday, an outage) that could
explain a swing.

Returning users must see the same variant they saw first. Counterexample: a
"small copy fix" applied to the control halfway through, after which neither arm
matches the version that was planned.
