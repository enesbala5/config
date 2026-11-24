# Licence policy: allowed, forbidden, unverified is blocked

**Feeds stage:** tooling-and-providers

For a soundtrack built from real recordings the licence gate is explicit, not a matter of taste. Allowed: CC0, public domain, CC BY 2.0-4.0, Mixkit free licences, Pixabay. Forbidden: NC, ND, SA, Sampling+, personal, custom, disputed. Unverified = blocked: do not use a file until its licence is confirmed on that item's own page. The auditor records `licence_seen` and `licence_confirmed` per item in the manifest; `audit.py` checks classification, ids vs URLs, decoded files, durations and credit lines, and the gate is exit 0 for exactly what the film uses. Counterexample: a Freesound CC BY clip is usable only if its attribution is carried into `CREDITS.md` and the video description.
