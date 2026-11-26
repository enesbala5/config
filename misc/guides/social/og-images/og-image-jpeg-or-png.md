# Use JPEG or PNG and declare the image type

**Feeds stage:** build

Prefer JPEG or PNG for OG images: WebP works on most but not all crawlers, so it is not a safe default. Derive the tag's `type` from the file extension (`jpg`/`jpeg` → `image/jpeg`, `png` → `image/png`, `webp` → `image/webp`) with `image/jpeg` as the fallback when the extension is unknown.
