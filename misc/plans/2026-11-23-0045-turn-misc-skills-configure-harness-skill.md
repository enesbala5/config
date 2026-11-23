# Plan: Turn misc/skills/configure-harness/SKILL.md int...

- Status: complete
- Created: 2026-11-23T00:22:03.885Z
- Project: `/home/e/config`

## Steps

- [x] 1. Turn misc/skills/configure-harness/SKILL.md int...
- [x] 2. One README.md under providers/<harness>/.
- [x] 3. Make the extension rule explicit and verify it.

## Plan

Plan:

1. **Turn `misc/skills/configure-harness/SKILL.md` into a thin router.** Keep the existing skill name and route requests to one of the four currently supported harnesses: Cursor, Pi, Herdr, and OpenCode. Read only the matching provider guide unless the request spans harnesses. If the target is unclear, ask rather than guessing from the harness running the session. **Risk:** A shortcut or integration can have owners on both sides; the router should allow reading both guides when needed.

2. **Add one `README.md` under `providers/<harness>/`.** Each guide will identify the canonical sources, what not to edit, and where to find apply and verification instructions. Keep the detailed procedures in the existing tool docs so there’s only one place to maintain them.
   - **Cursor:** Point to `misc/rules/general/`, the shared-rule pairing documented in `tools/pi/README.md`, and the separately managed Herdr Desktop hooks.
   - **Pi:** Point to `tools/pi/README.md` for tracked settings, keybindings, themes, and extensions. Distinguish those from generated model config and runtime state.
   - **Herdr:** Point to `tools/herdr/README.md` and distinguish TUI from Desktop/core so users follow the right reload and verification steps.
   - **OpenCode:** Point to `tools/opencode/README.md` and the Nix modules, not the live `cli.json` or `tui.json`.
   
   **Risk:** Copying setup commands into these guides would create two sources of truth. Keep each page focused on routing and ownership.

3. **Make the extension rule explicit and verify it.** Document that adding a harness takes one `providers/<id>/README.md` and one router row—no scripts, registry, or extra `SKILL.md`. Check that all four links resolve relative to the skill, that each guide identifies the right source from outside the config checkout, and that a missing checkout or guide prompts for its location rather than a live-config edit. **Risk:** Skill-relative links and checkout-relative paths can be confused; verify both separately. No rebuild or live configuration changes are needed.

**Files to change:**
- Update `misc/skills/configure-harness/SKILL.md`
- Add `misc/skills/configure-harness/providers/cursor/README.md`
- Add `misc/skills/configure-harness/providers/pi/README.md`
- Add `misc/skills/configure-harness/providers/herdr/README.md`
- Add `misc/skills/configure-harness/providers/opencode/README.md`

Estimated execution: **15 minutes**. No files changed. Waiting for your go-ahead.
