# Plan: Make cli.json the source of truth for personal ...

- Status: in progress
- Created: 2026-11-21T17:01:15.044Z
- Project: `/home/e/config`

## Steps

- [x] 1. Make cli.json the source of truth for personal ...
- [x] 2. Link just cli.json, not the whole directory.
- [ ] 3. Link and the Git workflow.

## Plan

Use the **Zed pattern for one file**: track `tools/opencode/cli.json` in `~/config` and have Home Manager link `~/.config/opencode/cli.json` directly to it. **One rebuild installs the link; it doesn’t copy or regenerate the file.** After that, edit the repo file and commit, push, and pull as usual. No rebuild for keybinding changes.

Plan:
1. **Make `cli.json` the source of truth for personal preferences.** Seed `tools/opencode/cli.json` from your current file: keybindings, theme selection, notifications, and display preferences. Keep MCP, providers, and custom theme definitions in Nix. Check whether `tui.nix` still needs to set any of the same preferences for older OpenCode versions before removing duplicates.
2. **Link just `cli.json`, not the whole directory.** Add `nix/nixos/modules/home/programs/opencode/cli.nix` using the same `mkOutOfStoreSymlink` approach as Zed. Back up and compare existing local files before the first rebuild so neither machine’s shortcuts get lost. Leave local plugins and runtime files alone.
3. **Verify the link and the Git workflow.** Check that a pulled keybinding change works on the second machine without a rebuild. If OpenCode offers an in-app edit, check whether it writes through the link or replaces it. If it replaces the link, use the repo file as the supported edit point rather than adding a sync script.

**Files:** `tools/opencode/cli.json`, `nix/nixos/modules/home/programs/opencode/cli.nix`, and `tui.nix` only if testing confirms its overlapping settings are redundant.

Step 1 of the original plan is settled: **Git-backed, like Zed.** No files changed; next is setting up the link.
