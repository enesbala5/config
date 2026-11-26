# Every shareable page needs the full static metadata block

**Feeds stage:** audit

Put the whole block in static HTML: title, description, Open Graph title, description, `url` and `type` (`website`, or `article` for blog posts), an OG image, and a Twitter card set to `summary_large_image` with its own title, description and absolute image URL. Missing `og:title`, `og:description` or `og:image` is the root cause of "no preview at all"; a missing or `summary` card type is the root cause of a plain-text card.
