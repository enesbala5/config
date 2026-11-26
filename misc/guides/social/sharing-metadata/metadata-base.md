# Set `metadataBase` for relative metadata URLs

**Feeds stage:** audit

In a Next.js App Router root layout, set `metadataBase: new URL('https://www.yourdomain.com')` whenever metadata contains relative URLs — without a base, relative canonical and OG URLs cannot be resolved to absolute ones. If the helper already emits absolute canonical and OG URLs, previews can work without it, but setting `metadataBase` in the root layout is still the pre-launch default.
