---
name: herdr-add-plugin
description: Install a Herdr plugin and record it in the config repo so a rebuilt machine can restore it. Use when the user installs a Herdr plugin, asks to add one, or wants a plugin synced to tools/herdr.
---

# Add a Herdr plugin

Install the plugin, then store only the parts a rebuild cannot recover from `plugins.json`. Checkouts and the registry stay runtime state.

Repo layout and the current plugins are in `tools/herdr/README.md`. The symlink module is `nix/nixos/modules/home/programs/herdr.nix`.

`herdr plugin install`, `plugin list`, `plugin link`, and `plugin config-dir` are fine outside a Herdr pane. Pane and agent control is the `herdr` skill and requires `HERDR_ENV=1`.

## Install

GitHub plugin, not already installed:

```sh
herdr plugin install <owner>/<repo> --yes
herdr plugin list
```

Local plugin (source you own, already in this repo):

```sh
herdr plugin link <plugin-dir>
```

If `herdr plugin list` already shows it enabled, skip the install.

## What to store

Do not copy `~/.config/herdr/plugins.json`, `github-installations/`, sockets, logs, or `session.json`. Herdr rewrites the registry.

| Kind | Store | Wire-up |
| --- | --- | --- |
| Local source you own | The plugin directory under `tools/herdr/plugins/<name>/` | Home-manager activation runs `herdr plugin link` once, skips when the plugin id is already in `plugins.json`, and never fails activation. Copy `herdrLinkAgentHead`. |
| GitHub plugin | The install command, the GitHub URL, and any user settings | Document both in `tools/herdr/README.md` under New-machine setup. Do not vendor the checkout. |
| Superseded plugin | An uninstall line in that same section | Do not keep the checkout. |

User settings:

1. Run `herdr plugin config-dir <plugin-id>`.
2. Read the plugin README for the settings filename. Bar uses `config.json` in that directory. Auto Title uses `~/.config/herdr-auto-title/config.env`, not the plugin config dir.
3. If the plugin has no settings file yet, create one under `tools/herdr/plugins/<plugin-id>/` using the upstream example. Do not invent values that change behavior.
4. Symlink that file with `home.file` and `mkOutOfStoreSymlink`, same as `plugins/auto-title/config.env` and `plugins/herdr-bar/config.json`.
5. On this machine, also `ln -s` the repo file onto the live path so it works before the next home-manager switch. The directory must already exist (`herdr plugin config-dir` creates it).

Keybinds go in `tools/herdr/config.toml`. That file is already symlinked.

Add a package to `herdr.nix` `home.packages` only when install cannot use a prebuilt binary. Auto Title needs `go`. Bar downloads a release binary and falls back to `cargo` only if the download fails, so it does not get a Rust package.

## After editing

Update the layout tree in `tools/herdr/README.md` when a new settings file or local plugin directory is added.

Do not commit unless the user asks.

Tell the user the one command a new machine still runs (`herdr plugin install …` or nothing, for a linked local plugin) and that `home-manager switch` picks up a new symlink.
