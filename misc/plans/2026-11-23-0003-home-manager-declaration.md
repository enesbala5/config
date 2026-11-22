# Plan: Reconcile the OpenCode preferences before remov...

- Status: in progress
- Created: 2026-11-22T23:20:45.439Z
- Project: `/home/e/config`

## Steps

- [x] 1. Reconcile the OpenCode preferences before remov...
- [x] 2. Generate the v2 CLI config from Nix.
- [x] 3. Thin configure-harness skill.
- [ ] 4. Migrate once, then verify two switches. First switch verified at 00:25 CET: Home Manager succeeded, `cli.json` and both backups matched their pre-switch checksums, and the installed OpenCode showed `Ctrl+T` for New session. Second switch pending sudo.

## Plan

**Make Nix the source of truth for OpenCode preferences.** Retire the writable symlink into the checkout, and add `configure-harness` as a small index of where each tool is configured—not a new configuration system.

Plan:
1. **Reconcile the OpenCode preferences before removing anything.** Compare the tracked `tools/opencode/cli.json`, the live file, its backups, and `tui.nix`. The live file has `session.thinking = "show"` and no custom keybindings; the tracked file has `"hide"` and includes the newer `Ctrl+G` editor binding. Keep the tracked keybindings unless their removal was intentional. Confirm whether thinking should be **shown** (live) or **hidden** (tracked) before migrating that setting. Keep the existing `github` theme; `stylix` appears in an older backup, not in the live file.
2. **Generate the v2 CLI config from Nix.** Replace the checkout-link declaration in `nix/nixos/modules/home/programs/opencode/cli.nix` with Nix-native preferences that generate the v2 `cli.json`. The pinned OpenCode is **2.2.5**, while Home Manager’s `programs.opencode.tui` generates `tui.json`, so don’t assume moving everything into `tui.nix` preserves behavior. Leave `tui.nix`, providers, and MCP alone unless testing shows an actual conflict. Before deleting the tracked JSON, verify that OpenCode loads the generated file and doesn’t fail or replace it during normal use.
3. **Add the thin `configure-harness` skill.** Use `manage-skill`’s create flow for `misc/skills/configure-harness/SKILL.md`. Add one row per tool: **Pi** → `tools/pi/README.md`; **Cursor** → the Cursor rules section in that same README; **OpenCode** → `tools/opencode/README.md`; **Herdr** → `tools/herdr/README.md`, with `herdr --help` for CLI discovery. Update the OpenCode README to say **edit the Nix modules, not `~/.config/opencode/cli.json`**. No separate provider framework or duplicated docs.
4. **Migrate once, then verify two switches.** Close OpenCode and preserve the current local file and existing backups under distinct names before the first switch. On any other machine, inspect the path first: archive a regular file; remove only a symlink verified to be the old checkout link. Remove `tools/opencode/cli.json`, switch, and confirm Home Manager succeeds, OpenCode loads the intended theme and shortcuts, and the config no longer resolves into the checkout. Switch again after normal OpenCode use to check that the collision doesn’t recur. Don’t change the host-wide backup policy or use `force = true`.

**Files to change:** `misc/skills/configure-harness/SKILL.md` (add), `nix/nixos/modules/home/programs/opencode/cli.nix` (replace the checkout-link declaration), `tools/opencode/README.md` (update), and `tools/opencode/cli.json` (remove after migration). No changes made.
