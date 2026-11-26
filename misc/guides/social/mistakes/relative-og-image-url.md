# Relative OG image URLs produce broken previews

**Feeds stage:** verify

A relative image path such as `/images/og/home.jpg` is the listed root cause of a broken preview image: crawlers need an absolute URL. Resolve the path against the site base URL (`https://www.yourdomain.com/images/og/home.jpg`) before putting it in `og:image`, `og:image:secure_url` or `twitter:image`.
