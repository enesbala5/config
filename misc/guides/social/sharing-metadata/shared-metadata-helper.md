# Use one helper across static and dynamic pages

**Feeds stage:** audit

Route every shareable page through the same `buildSocialMetadata({ title, description, path, image, imageAlt })` helper: `export const metadata = ...` for static pages, `generateMetadata({ params })` for blog posts and tool pages, and a spread of the helper plus `metadataBase` for the homepage. One helper keeps canonical URLs, OG blocks, card type and image handling consistent; ad-hoc per-page metadata is how a shareable page ends up missing tags.
