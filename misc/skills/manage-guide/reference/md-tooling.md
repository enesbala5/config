# Saving web pages and X posts as Markdown

Sources are archived **verbatim** as `.md` files. Nothing is summarized. Every archive file starts with frontmatter:

```yaml
---
title: "Article title"
source: https://example.com/article
author: "Author or publication"
published: "2026-01-01"
captured: "2026-11-22"
---
```

Then the full body. X posts use the same shape; `source` is the post URL.

## Portable path (required fallback)

No dedicated browser tool is required. Use ordinary shell, HTTP and Node.

1. Create a scratch dir outside the repo, e.g. `/tmp/<name>-md`, and install the converter dependencies once:

   ```sh
   mkdir -p /tmp/guide-md && cd /tmp/guide-md
   npm install --no-audit --no-fund jsdom @mozilla/readability turndown
   ```

2. Download the page:

   ```sh
   curl -sSL --max-time 30 'https://example.com/article' -o /tmp/guide-md/raw.html
   ```

3. Convert with the script shipped in this skill (paths are relative to the skill folder):

   ```sh
   NODE_PATH=/tmp/guide-md/node_modules \
     node <skill>/scripts/convert-html-to-md.js /tmp/guide-md/raw.html \
       <dir>/misc/sources/my-article.md \
       --source-url 'https://example.com/article' \
       --title 'Article title' --author 'Author' --published '2026-01-01'
   ```

   The script extracts the article with Readability, converts it with Turndown, and writes the frontmatter. A plain HTML→MD fallback is used if Readability fails.

4. X posts: the website is login-gated to automation, so use the public JSON API instead of HTML:

   ```sh
   node <skill>/scripts/fetch-x-to-md.js <status-id> <dir>/misc/sources/my-post.md
   ```

   Endpoint: `https://api.fxtwitter.com/status/<status-id>` — `tweet.article.content.blocks[]` holds long-form article text (`type`, `text`); `tweet.text` holds a plain post. Fallback: `https://api.vxtwitter.com/<handle>/status/<status-id>`. Both may be rate-limited; retry once with the other endpoint, then report the URL rather than saving a stub.

## Optional browser shortcut (harness-specific, not required)

If the environment provides browser automation (for example Playwright MCP), it can save rendered HTML without a `curl` round trip:

1. Navigate to the URL.
2. Evaluate `() => document.documentElement.outerHTML` with the tool's "save result to file" option, targeting a path **inside the workspace root** — browser tools commonly refuse absolute paths outside it (allow-listed roots are typically the workspace root and its `.playwright-mcp/` folder).
3. Feed the saved file to `convert-html-to-md.js` as above.

Useful companion calls when a page is dynamic: a page snapshot/accessibility tree to confirm content rendered, and a network-request listing if the HTML save needs a different response. Browser automation may still hit a login wall on X — that is normal; use the API path.

## Host notes

- This host has `node` and `npm`, but no `pandoc`, `html2text`, `lynx` or `python3`. Do not depend on them.
- npm installs need network access on first use; after that, reuse the scratch dir.
- Never embed credentials. Public endpoints only; no API keys are used.

## Verification

- Open the tail of every saved file and confirm the article actually ends (not cut off at a "Subscribe" or login prompt).
- Check word count is plausible for the source; a suspiciously short body means the extraction failed.
- Run `node <skill>/scripts/verify-guide.js <dir>`.
- If a page is behind a paywall or login, report it as a lead — do not save a partial archive and pretend it is complete.
