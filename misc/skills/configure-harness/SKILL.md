---
name: configure-harness
description: Find and edit the canonical configuration for coding agents and their workspace managers. Use when changing harness settings, keybindings, themes, rules, or integrations.
---

# Configure a harness

1. Identify the harness the request targets. Read only its provider guide, or read each relevant guide for a cross-harness change. If the target is unclear or not listed, ask which harness and where its config is managed; don't assume it's the one running the session.

   | Harness | Provider guide (relative to this skill) |
   | --- | --- |
   | Cursor | [`providers/cursor/README.md`](providers/cursor/README.md) |
   | Herdr | [`providers/herdr/README.md`](providers/herdr/README.md) |
   | OpenCode | [`providers/opencode/README.md`](providers/opencode/README.md) |
   | Pi | [`providers/pi/README.md`](providers/pi/README.md) |

2. Locate the `enesbala5/config` checkout from the user's path, the resolved skill location if it's inside the checkout, or `~/config`. Verify the checkout before editing (for example, with `git -C <checkout> remote -v`). Paths inside provider guides are relative to the checkout root, not the skill directory or current working directory. If the checkout or a guide is missing, ask for its location rather than guessing a live config path.
3. Edit the canonical source identified by the guide, not the deployed file. Follow the linked repo documentation to apply and verify the requested change.

## Add a harness

Create `providers/<id>/README.md` (lowercase kebab-case) and add one row to the table. Use **Start here** and **Apply and verify** sections to identify the canonical sources, runtime files to leave alone, and the existing docs for applying and checking changes. Don't duplicate setup procedures or add another `SKILL.md`, script, or registry.
