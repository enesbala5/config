# OG images must be reachable by an unauthenticated GET

**Feeds stage:** build

A crawler must be able to fetch the image with a plain GET and no authentication or gated session. If the URL only resolves behind a login or redirect-based gate, the card shows a broken image even when the metadata tags are correct.
