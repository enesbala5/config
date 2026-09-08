---
name: playwright-cdp
description: Connect Playwright to the already-running Helium (preferred) or Chrome browser over CDP. Use when automating the real desktop browser, taking screenshots, clicking, filling forms, scraping a logged-in session, driving Playwright MCP, or when the user mentions Playwright, Helium CDP, chrome remote debugging, or connectOverCDP.
---

# Playwright + Helium CDP

On this machine Playwright talks to **Helium** (Chromium, lighter than a second Chrome) over Chrome DevTools Protocol. Do not download Playwright's Chromium. Do not launch an isolated browser unless the user asks for `--isolated`.

NixOS: host Chromium from `playwright install` will not work. Packaged browsers live in `PLAYWRIGHT_BROWSERS_PATH` for isolated Playwright Test only.

## Before any automation

```bash
helium-cdp
```

Prints `http://127.0.0.1:9222` when ready. If Helium was started without the debug port, quit Helium fully and reopen it (Super+H or the Helium desktop entry). Both pass the CDP flags; the app launcher is `xdg.desktopEntries.helium` (installed as `helium.desktop`).

Chrome fallback: `helium-cdp --chrome`

Use `127.0.0.1`, not `localhost` (IPv6).

## Prefer Cursor Playwright MCP

If the `playwright` MCP server is connected, use those tools. It is configured with `--cdp-endpoint=http://127.0.0.1:9222` via `scripts/browser/playwright-mcp.sh`. If MCP fails, run `helium-cdp` then ask the user to reconnect the Playwright MCP server.

## Shell scripts (no MCP)

Install `playwright-core` once (no browser download):

```bash
mkdir -p /tmp/playwright-cdp
cd /tmp/playwright-cdp
npm init -y >/dev/null
npm install playwright-core
```

```bash
cd /tmp/playwright-cdp && node -e '
const { chromium } = require("playwright-core");
(async () => {
  const browser = await chromium.connectOverCDP("http://127.0.0.1:9222");
  const context = browser.contexts()[0] || await browser.newContext();
  const page = context.pages()[0] || await context.newPage();
  await page.goto("https://example.com", { waitUntil: "domcontentloaded", timeout: 15000 });
  await page.screenshot({ path: "/tmp/playwright-cdp.png" });
  await browser.close();
})().catch((err) => { console.error(err); process.exit(1); });
'
```

`browser.close()` disconnects Playwright. It does not quit Helium.

## Common actions

```js
await page.goto(url, { waitUntil: "domcontentloaded", timeout: 15000 });
await page.click("button.submit");
await page.fill("input[name=email]", "user@example.com");
await page.keyboard.press("Enter");
await page.screenshot({ path: "/tmp/shot.png", fullPage: true });
const title = await page.evaluate(() => document.title);
```

Avoid `waitUntil: "networkidle"` on heavy sites.

List tabs: `context.pages()`. New tab: `context.newPage()`. Find by URL: `pages().find(p => p.url().includes("..."))`.

Write one-off scripts to `/tmp/playwright-test-*.js`, not into git repos.

## Isolated Playwright Test (not Helium)

Only when the user wants a clean test browser, not their session:

- `PLAYWRIGHT_BROWSERS_PATH` and `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1` are set by Home Manager.
- Pin `@playwright/test` to the same version as nixpkgs `playwright-driver`.
- Or launch Helium as the executable: `launchOptions.executablePath` = `process.env.PLAYWRIGHT_MCP_EXECUTABLE_PATH`.

## Troubleshooting

- CDP down, Helium up → quit Helium, `helium-cdp`.
- `npx` / MCP missing `node` → NixOS rebuild so `nodejs` is on PATH, then restart Cursor.
- Port in use by something else → `ss -tlnp | grep 9222`.
