# OpenCode configuration

Edit the [OpenCode Nix modules](../../nix/nixos/modules/home/programs/opencode/),
not `~/.config/opencode/cli.json` or `tui.json`.

- `wrapper.nix` defines v2 CLI preferences (`cliPreferences`), including
  keybindings, the theme selection, and display and notification settings.
  It passes them to OpenCode at launch as `OPENCODE_CLI_CONFIG_CONTENT`.
  Nix preferences take precedence for the keys they define; OpenCode can still
  write its local file, but Home Manager does not install or back it up.
- `providers.nix`, `mcp.nix`, and `theme.nix` configure providers, MCP, and the
  custom theme. `tui.nix` supplies the legacy TUI settings.

Apply changes with the normal NixOS switch, then start a new OpenCode process.
Check `systemctl is-active home-manager-$USER.service` and smoke-test the changed
preference (for example, `Ctrl+T` should open a new session).

## Retiring the old checkout link

On each machine, inspect `~/.config/opencode/cli.json` before switching. If it
is a symlink from the old setup, save any preferences you need and remove only
that link. If it is a regular file, leave it and its backups in place. Do not
create a replacement link: OpenCode owns this path now.
