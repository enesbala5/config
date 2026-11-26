# Serve OG images over HTTPS with `secureUrl` set

**Feeds stage:** build

Serve the image over HTTPS and set the OG image `secureUrl` equal to its `url` so an explicit HTTPS version is declared. A `http://` image URL is a broken-preview risk; the checklist requires both values to be present and HTTPS.
