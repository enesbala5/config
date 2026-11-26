# Keep OG images under 8MB

**Feeds stage:** build

Keep each OG image file below 8MB — that is Facebook's limit, so an over-limit file will not unfurl there. Check `content-length` on the served URL rather than trusting the source asset.
