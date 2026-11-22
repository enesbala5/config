---
name: configure-harness
description: Find and edit the canonical configuration for Pi, Cursor, OpenCode, or Herdr. Use when changing harness settings, keybindings, themes, rules, or integrations.
---

# Configure a harness

In the `enesbala5/config` checkout, read the guide for the tool you’re changing:

| Tool | Start here |
| --- | --- |
| Pi | `tools/pi/README.md` |
| Cursor | `tools/pi/README.md` for shared rules and `misc/rules/general/` for Cursor rule sources |
| OpenCode | `tools/opencode/README.md`; edit Nix, never `~/.config/opencode/cli.json` |
| Herdr | `tools/herdr/README.md` for settings and Nix modules; `herdr --skill` for CLI usage, or `herdr --help` if unavailable |

Edit the source identified by the guide, not the deployed file. Follow the guide to apply and verify the change. If the checkout or guide is missing, ask for its location rather than guessing at a live config path.
