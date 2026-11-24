# Drop any angle already delivered in the lookback window

**Feeds stage:** social

Before drafting, read the recent-delivery ledger and drop every commit, PR or
angle already delivered in the previous 14 days. A repeated angle is worse than
a thin batch.

The ledger is keyed on ids and angles for exactly this reason: reposting the
same change under a fresh opener is still a repeat. Record each delivered
option (source id, target, angle, text, timestamp) so the next batch can check
against it, and keep the ledger as the only archive — no separate batch files,
reports or scratch documents.

A commit message is not an angle either. "Fix OG image filename" is not a post;
the reason behind the fix can be, provided that reason has not already been
told.
