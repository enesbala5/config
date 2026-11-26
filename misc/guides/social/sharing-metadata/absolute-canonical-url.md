# The canonical URL must be the absolute page URL

**Feeds stage:** audit

Build the canonical as site base URL plus page path (for example `https://www.yourdomain.com/blog/my-post`) and set it as `alternates.canonical` as well as `openGraph.url`. A relative or missing canonical leaves crawlers without an authoritative URL for the card.
