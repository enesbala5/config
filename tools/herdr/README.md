# Herdr

Terminal workspace manager for AI coding agents. This directory is the
version-controlled source of truth for the parts of `~/.config/herdr` that are
worth keeping; everything else there is runtime state.

## Layout

```
tools/herdr/
├── config.toml                     # ~/.config/herdr/config.toml (symlinked)
├── plugins/
│   ├── auto-title/config.env       # ~/.config/herdr-auto-title/config.env (symlinked)
│   └── agent-head/                 # local plugin: leading glyph + tab title
│       ├── herdr-plugin.toml
│       ├── run.sh
│       └── head.js
└── README.md
```

Home-manager (`nix/nixos/hosts/framework-13/home/default.nix`) symlinks
`config.toml` and `plugins/auto-title/config.env` into place. It does **not**
touch the rest of `~/.config/herdr`, because Herdr writes its own state there
(`plugins.json`, socket, logs, `session.json`, plugin checkouts).

## New-machine setup

Plugin registration is **runtime state in `~/.config/herdr/plugins.json`**, not
Nix-managed, because Herdr rewrites that file.

- **Agent Head** (local plugin) is linked automatically by a home-manager
  activation (`home.activation.herdrLinkAgentHead` in
  `nix/nixos/hosts/framework-13/home/default.nix`). It is idempotent — it skips
  when `local.agent-head` is already in `plugins.json`, and it never fails the
  activation — so a fresh machine gets it on the first `home-manager switch`.
  Nothing to run by hand.
- **Auto Title** is installed from GitHub (network + Go build) and stays a
  manual, one-time step per machine:

```sh
herdr plugin install kryptamine/herdr-auto-title --yes

herdr plugin list          # verify it is present and enabled
```

If you ever had the old spinner plugin, drop it — `$head` superseded it:

```sh
herdr plugin uninstall hasuwini77.spinner   # only if `herdr plugin list` shows it
```

Reload config after edits:

```sh
herdr config check && herdr server reload-config
```

Prerequisites on the machine: `go` (Auto Title), `node` (Agent Head).

## Sidebar agents panel

`config.toml` renders each agent as two lines:

```
⣾ pi - config          # $head = state glyph + tab title (no separator)
  pi · config          # agent · workspace
```

`$head` is a single custom token written by the local **Agent Head** plugin:

- one token means Herdr inserts no ` · ` separator between glyph and title
  (its separator is hardcoded in `src/ui/sidebar/tokens.rs`; only the built-in
  `state_icon` gets a bare space);
- `working` animates a braille spinner, everything else is a static glyph:
  `✓` done, `○` idle, `×` blocked, `·` unknown;
- `rules` in `config.toml` tint the token per state. The tint covers the title
  too; delete the `rules` list for a neutral title (the glyph shape still
  distinguishes states).

Agent Head is a detached daemon (Herdr startup hooks are one-shot, not
supervised). It refreshes each token with a TTL, so if it dies the glyph
expires instead of freezing, and the next Herdr start relaunches it. Restart it
by hand with:

```sh
herdr plugin action invoke restart --plugin local.agent-head
```

Tunables (spinner frames, intervals, static glyphs, disable) live in
`$HERDR_PLUGIN_CONFIG_DIR/config.json`; see `DEFAULTS` in
`plugins/agent-head/head.js`.
