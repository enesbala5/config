# Run the pre-launch social metadata checklist

**Feeds stage:** verify

Before calling a public page shareable, confirm every item:

- [ ] `metadataBase` set in root layout
- [ ] All shareable pages use the shared `buildSocialMetadata` helper
- [ ] OG image URLs are absolute and start with `https://`
- [ ] `secureUrl` equals the OG image `url`
- [ ] Image is 1200×630px, under 8MB, HTTPS
- [ ] `twitter:card` is `summary_large_image`, not `summary`
- [ ] Image alt text present
- [ ] Tags visible in raw HTML, not JavaScript-rendered
- [ ] All platform debuggers show the correct preview
- [ ] Cache refreshed on every platform after deployment
