# Check OG image headers with `curl -I`

**Feeds stage:** verify

Confirm the image is actually served as expected: `curl -sI https://www.yourdomain.com/images/og/home.jpg | grep -i "content-type\|content-length\|status"`. This shows the response status, MIME type and byte size — the quick check for a broken or wrong-sized image URL.
