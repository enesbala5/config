# Check raw HTML for `og:` and `twitter:` tags

**Feeds stage:** verify

Fetch the page as a crawler sees it and grep the response: `curl -s https://www.yourdomain.com/blog/my-post | grep -i "og:\|twitter:"`. If no tags appear, they are being added by JavaScript and are not crawlable; move them into `export const metadata` or `generateMetadata` and re-run the check.
