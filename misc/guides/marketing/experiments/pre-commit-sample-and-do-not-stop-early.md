# Pre-commit to sample size and do not stop on an early lead

**Feeds stage:** verify

Looking at results before the pre-calculated sample size is reached, then
stopping when the variant looks significant, inflates the false-positive rate.
Early significance is often regression to the mean, a day-of-week effect, or a
shift in audience mix — not the treatment working.

Commit to sample and duration before launch and honour that commitment even when
you are ahead. An overpowered test is not a problem; an early stop is.

Two legitimate exceptions, both declared before launch: stop immediately if a
guardrail metric is significantly negative, or use a sequential/Bayesian method
built to handle multiple looks at the data. Do not retrofit either exception
after seeing a promising number.
