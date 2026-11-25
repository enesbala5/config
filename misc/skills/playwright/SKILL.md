---
name: playwright
description: Drive the dedicated Playwright Helium browser over CDP, or the human's Helium/Chrome when explicitly asked. Use when automating the real desktop browser, taking screenshots, clicking, filling forms, scraping, driving Playwright MCP, or when the user mentions Playwright, Helium CDP, chrome remote debugging, or connectOverCDP.
---

# Playwright + Helium CDP

Playwright has its **own dedicated Helium instance** on CDP port **9333**. The
human's browsing Helium stays on 9222 and is never automated by default.

The dedicated instance has its own profile (`~/.cache/playwright-agent-helium`)
and one fixed window, parked on workspace 11 at launch. Playwright pages open as
**tabs in that one window** — no new windows, no title markers, no hooks that
move windows around. If you need to inspect it visually, go to workspace 11 or
find it with `hypruse desktop`.

Do not download Playwright's Chromium. Do not launch an isolated browser unless
the user asks for `--isolated`.

**Hosts:** this is the `framework-13` desktop workflow. On `home-server`,
browser automation is a separate headless MCP service at
`http://10.0.100.1:8931/mcp` for the Incus agent VMs — don't use this setup
there.

NixOS: host Chromium from `playwright install` will not work. Packaged browsers
live in `PLAYWRIGHT_BROWSERS_PATH` for isolated Playwright Test only.

## Before any automation

```bash
playwright-helium
```

Prints `http://127.0.0.1:9333` when ready. It is idempotent: if the agent
browser is already up it just prints the URL. `playwright-mcp` calls this for
you, so a connected Playwright MCP server usually needs no manual step.

Use `127.0.0.1`, not `localhost` (IPv6).

To start the human's browsing Helium with CDP (not for automation):
`helium-cdp` → `http://127.0.0.1:9222`. Chrome fallback for that:
`helium-cdp --chrome`.

## Visual evidence

Use `page.screenshot(...)` / `locator.screenshot(...)` for page or element
screenshots; use `hypruse screenshot --window ADDR` for desktop/window images.
For video, follow sibling `screenrecord/SKILL.md` (sampled isolated windows or
native display recording). Playwright `recordVideo` must be set when creating
a context; it cannot be enabled retroactively on an existing CDP context.

## Prefer browser MCP (optional)

If the `playwright` MCP server is connected, use those tools. `playwright-mcp.sh`
starts/reuses the agent browser and runs
`@playwright/mcp --cdp-endpoint=http://127.0.0.1:9333`. After changing this
endpoint, restart the MCP client so it picks up the new port.

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
  const browser = await chromium.connectOverCDP("http://127.0.0.1:9333");
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

List tabs: `context.pages()`. New tab: `context.newPage()` (opens in the agent
window, not a new window). Find by URL: `pages().find(p => p.url().includes("..."))`.

Write one-off scripts to `/tmp/playwright-test-*.js`, not into git repos.

## Isolated Playwright Test (not the agent browser)

Only when the user wants a clean test browser, not the agent session:

- `PLAYWRIGHT_BROWSERS_PATH` and `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1` are set by Home Manager.
- Pin `@playwright/test` to the same version as nixpkgs `playwright-driver`.
- Or launch Helium as the executable: `launchOptions.executablePath` = `process.env.PLAYWRIGHT_MCP_EXECUTABLE_PATH`.

## Troubleshooting

- Agent CDP down → run `playwright-helium`; check `ss -tlnp | grep 9333`.
- `npx` / MCP missing `node` → NixOS rebuild so `nodejs` is on PATH, then restart the MCP client.
- Agent window disappeared → `playwright-helium` reopens it on workspace 11.
- Need the human's browser for a logged-in session → they must explicitly ask; use `helium-cdp` (9222).
