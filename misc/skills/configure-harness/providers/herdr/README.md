# Herdr

## Start here

Read `tools/herdr/README.md` to distinguish the TUI from Desktop/core before choosing a source. The TUI uses `tools/herdr/config.toml`; Desktop keybindings live in `tools/herdr/desktop/keys.json`. The same guide identifies the published layout submodule, plugin sources, and Home Manager modules. Don't edit deployed config or runtime state in place.

## Apply and verify

Use the TUI config check and reload documented in the repo guide for TUI changes. For Desktop/core, follow the relevant section of that guide and verify in the Desktop client rather than the TUI. For TUI CLI discovery, use `herdr --skill` or fall back to `herdr --help`.
