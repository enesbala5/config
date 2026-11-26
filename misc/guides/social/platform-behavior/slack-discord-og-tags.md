# Slack and Discord both use OG tags and cache them

**Feeds stage:** audit

Both Slack and Discord build embeds from Open Graph tags and both cache previews. Discord additionally supports `og:type = article` for richer embeds, so set the type deliberately rather than defaulting everything to `website`.
