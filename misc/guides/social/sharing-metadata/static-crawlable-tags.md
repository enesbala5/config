# Crawlers do not run JavaScript

**Feeds stage:** audit

Platform crawlers read the HTML they fetch, so tags injected by client-side JavaScript are invisible to them. Declare metadata with `export const metadata` on static pages and `generateMetadata` on dynamic pages so `og:` and `twitter:` tags are present in the raw response; a tag that never appears in raw HTML was added by JS.
