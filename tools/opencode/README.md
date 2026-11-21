# OpenCode CLI preferences

Edit [cli.json](cli.json) here, then commit and push it. On another device,
pull the repo and restart OpenCode if it's running. Preference changes don't
require a Nix rebuild once the link is installed.

## First setup on each device

1. Close OpenCode. If `~/.config/opencode/cli.json` already exists and is not
   linked to this checkout, back it up outside the repo and compare it with
   this file. Merge any preferences you want to keep, then move the local file
   out of the way before switching.
2. Run the normal NixOS/Home Manager switch with OpenCode enabled. Confirm
   that `readlink -f ~/.config/opencode/cli.json` points to
   `~/config/tools/opencode/cli.json`.
3. Start OpenCode and check a shortcut, such as `Ctrl+T` for a new session.

Use the repo file as the edit point. If you change a preference inside
OpenCode, check both the link and `git diff -- tools/opencode/cli.json`.
An app that replaces the link instead of writing through it leaves the change
local; merge it into the repo file, move the local file aside, and run the
switch again to restore the link.

Providers, MCP, and custom theme definitions stay in Nix. The legacy
`tui.json` remains managed by Home Manager. Do not add credentials, sessions,
or machine-local plugins here.
