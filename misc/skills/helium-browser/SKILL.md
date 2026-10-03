---
name: helium-browser
description: "Drive the home-server Helium browser over Playwright MCP and attach traces or video."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [Browser, Playwright, Helium, Testing]
    related_skills: [openhands]
---

# Helium browser testing

Browser checks run on the **home-server host**, not inside this VM. Hyprland is not involved. Helium is headless, on its own profile (`/var/lib/helium-browser/profile`), not the profile you use at the desk.

## Endpoint

Playwright MCP is already registered as `helium-browser`:

`http://10.0.100.1:8931/mcp`

Use those tools (`browser_navigate`, `browser_snapshot`, `browser_click`, …). Do not start Chromium, Chrome, or Helium inside the guest.

One browser is shared by Hermes and OpenHands. Do not leave a session running while the other agent is testing.

## Hermes-side

The guest config pins `browser.backend: "off"`, so Hermes runs no browser driver of its own here — the `helium-browser` MCP tools are the only browser surface. Do not reach for `browser_exec`; use the MCP tools above.

`tools/incus/configure-browser-mcp.sh hermes` writes both the MCP server and that key, and `hermes-vm-manage.sh start` re-runs it, so the config survives a VM rebuild.

## Recordings

Traces, webm video, and auto-named screenshots land in:

`/var/lib/helium-browser/recordings`

That path is the same on the host and in this guest when the `helium-recordings` disk is attached. After a check, attach the newest `.webm` or `trace.zip` to the GitHub PR, or hand the file to Hermes so it can be sent on. Open a trace locally with `npx playwright show-trace <file>`.

`/etc/helium-browser.env` repeats the URL and the recordings path.
