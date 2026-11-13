# hypruse (Framework 13)

Computer use for Hyprland: MCP server that gives agents screenshots, window
tree / AT-SPI actions, and Wayland pointer + keyboard (`grim`,
`zwlr_virtual_pointer_v1`, `wtype`). No root, portals, or ydotool.

Tracked against [enesbala5/config#108](https://github.com/enesbala5/config/issues/108).
Upstream: [IlyasKhallouki/hypruse](https://github.com/IlyasKhallouki/hypruse).

## What this module does

1. Flake input `hypruse` in `nix/nixos/flake.nix` (`inputs.nixpkgs.follows = "nixpkgs"`).
2. Imports upstream `homeModules.default` and sets `programs.hypruse.enable = true`.
3. Registers the stdio server in `misc/mcp/mcp.json` as `hypruse` (synced to Cursor / pi / Zed; OpenCode picks it up on rebuild).

Package override: skip `test_claude_plugin_runs_its_own_locked_source` until upstream
includes `uv.lock` in the flake `fileset` (hypruse 0.15.0).

Binary after switch: `/etc/profiles/per-user/e/bin/hypruse`.

## Smoke test (after rebuild)

In a real Hyprland session on this laptop:

```sh
hypruse doctor
```

Or without installing: `nix run github:IlyasKhallouki/hypruse -- doctor`.

## Optional env

Set under `programs.hypruse.env` in `default.nix`, for example:

- `HYPRUSE_BACKGROUND = "1"` — agent workspaces while you keep yours
- `HYPRUSE_READONLY = "1"` — observe without injecting input
