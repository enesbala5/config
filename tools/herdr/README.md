# Herdr

Terminal workspace manager for AI coding agents. This directory is the
version-controlled source of truth for the parts of `~/.config/herdr` that are
worth keeping; everything else there is runtime state.

## Layout

```
tools/herdr/
├── config.toml                     # ~/.config/herdr/config.toml (symlinked)
├── desktop/
│   ├── keys.json                   # ~/.config/herdr-app/keys.json (symlinked)
│   └── mods/toast/                 # glass toast UI; desktop entry re-copies after start
├── integrations/
│   └── cursor/                     # Cursor → herdr-core OSC 7501 bridge
│       ├── desktop-status.sh       # ~/.cursor/herdr-desktop-status.sh
│       ├── hooks.json              # ~/.cursor/hooks.json (desktop hosts)
│       └── README.md
├── plugins/
│   ├── auto-title/config.env       # ~/.config/herdr-auto-title/config.env (symlinked)
│   ├── herdr-bar/config.json       # ~/.config/herdr/plugins/config/herdr-bar/config.json (symlinked)
│   ├── ovis/env                    # ~/.config/herdr/plugins/config/devswha.ovis/env (symlinked)
│   └── agent-head/                 # local plugin: leading glyph + tab title
│       ├── herdr-plugin.toml
│       ├── run.sh
│       └── head.js
└── README.md
```

Home-manager (`nix/nixos/modules/home/programs/herdr/`, enabled per host)
symlinks `config.toml`, `plugins/auto-title/config.env`,
`plugins/herdr-bar/config.json`, `plugins/ovis/env`, and (when desktop is
on) `desktop/keys.json` plus the Cursor desktop bridge
(`integrations/cursor/`) into place. It does **not** touch the rest of
`~/.config/herdr` or `~/.config/herdr-app`, because those apps write their
own state there (`plugins.json`, sockets, logs, `session.json`, mods).
When desktop is on, the Herdr Desktop launcher wraps `herdr-app` so it
re-copies `desktop/mods/toast/` into `~/.config/herdr-app/mods/toast`
after start (Herdr restores the shipped toast mod every launch).

## New-machine setup

Plugin registration is **runtime state in `~/.config/herdr/plugins.json`**, not
Nix-managed, because Herdr rewrites that file.

- **Agent Head** (local plugin) is linked automatically by a home-manager
  activation (`home.activation.herdrLinkAgentHead` in
  `nix/nixos/modules/home/programs/herdr/plugins.nix`). It is idempotent — it skips
  when `local.agent-head` is already in `plugins.json`, and it never fails the
  activation — so a fresh machine gets it on the first `home-manager switch`.
  Nothing to run by hand.
- **Auto Title** is installed from GitHub (network + Go build) and stays a
  manual, one-time step per machine:

```sh
herdr plugin install kryptamine/herdr-auto-title --yes

herdr plugin list          # verify it is present and enabled
```

The installed checkout is patched so a tab with an agent leads its title with
that agent's Herdr Agent Icons mark. Copy
`plugins/auto-title/agenticon.go` to `internal/resolver/agenticon.go` and, in
`nameTab` after `Resolve`, set `decision.Name = logo + decision.Name` when
`resolver.AgentLogo(tab.Context)` is non-empty. `herdr plugin update` rebuilds
from upstream and drops both edits. Rebuild with
`go build -o herdr-auto-title ./cmd/herdr-auto-title`, then
`herdr plugin action invoke restart --plugin herdr.auto-title`.

- **Bar** ([jeffarese/herdr-bar](https://github.com/jeffarese/herdr-bar)) is
  installed from GitHub. The install downloads a prebuilt binary and falls
  back to `cargo` only if that download fails. Settings are
  `plugins/herdr-bar/config.json`. Keybinds in `config.toml`: `prefix+k` opens
  everything (`herdr-bar.open`); `ctrl+p` opens `%` panes and `ctrl+alt+p`
  opens `@` agents, via `plugins/herdr-bar/open.sh` (one config cannot hold
  two scopes). Kitty maps physical Ctrl+Shift+P to that Ctrl+Alt+P sequence.
  Kitty also owns Ctrl+Tab and Ctrl+Shift+Tab, so it forwards them as CSI-u
  (`\x1b[9;5u`, `\x1b[9;6u`) and Herdr binds those to next / previous tab.
  Kitty's own tabs stay on Ctrl+Shift+Left / Ctrl+Shift+Right.
  Ctrl+T creates a tab and Ctrl+W closes one. Kitty does not bind those.
  While Auto Title is enabled, Bar
  skips its own automatic tab renames.

```sh
herdr plugin install jeffarese/herdr-bar --yes
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
  [logo] pi · config   # $vendor = icon + agent name, then workspace
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

## Clients

The TUI and the desktop app do not share sessions. Checked against upstream
[herdr-app#306](https://github.com/herdrdev/herdr-app/issues/306) and the two
config directories: the TUI uses `~/.config/herdr` (this `config.toml`, the
plugins, `herdr.sock`). `herdr-core` uses `~/.config/herdr-core/config.toml`
and its own socket under `$XDG_RUNTIME_DIR/herdr-core/`. Agent Head, Auto
Title, Bar, and `config.toml` apply to the TUI. herdr-gpui is a client of the
TUI daemon, so it sees those sessions. The desktop app sees core sessions.

| Piece | Version | Where |
| --- | --- | --- |
| TUI `herdr` | 0.9.5 | `nixpkgs-herdr` (cache.nixos.org). Latest release. The flake's master is newer and is not cached. |
| `herdr-core` / `hc` | 0.1.18 | release tarball. The cached nixpkgs build is 0.1.15 and is missing the Linux fixes after that. |
| `herdr-app` | 0.1.13 | release tarball. The cached nixpkgs build is 0.1.10. |
| herdr-gpui | pinned flake | `modules.home.herdr.gpui` |
| Ovis | 0.4.22 | `modules.home.herdr.mobile.enable` |

`modules.home.herdr.desktop.enable` installs the desktop app and herdr-core,
and symlinks `desktop/keys.json`. Those keys mirror the TUI's prefix-free
chords: Ctrl+T / Ctrl+W for new / close tab, Ctrl+Tab family for tab
cycling, Ctrl+P / Ctrl+Alt+P for the picker, Ctrl+Shift+K / Ctrl+Shift+P
for the command palette. Ctrl+W steals readline word-delete inside panes
(same tradeoff as the TUI). `framework-13` enables desktop + gpui;
`home-server` is TUI-only.

### Desktop Agents sidebar (Cursor)

Desktop only lists agents that emit OSC 7501. Cursor CLI does not, so tabs
started from **+ → Cursor** stay invisible in the Agents panel while the TUI
still detects them. Cursor hooks also have no controlling tty, so a bare
`printf > /dev/tty` never reaches the pane. `integrations/cursor/` resolves
the pane pts via `hc get $HC_TERMINAL_ID` and writes OSC 7501 there. Details:
`integrations/cursor/README.md`.

## Phone

Ovis ([devswha/ovis](https://github.com/devswha/ovis)) follows the TUI
(`OVIS_RUNTIME=herdr` in `plugins/ovis/env`). The desktop app's core is a
different socket, and this config does not use it.

The relay stays off (`OVIS_TAILSCALE_SERVE_ONLY=1`). Anonymous usage counts
are off (`OVIS_TELEMETRY=0`). Ovis binds `127.0.0.1:7317`. The phone reaches
it through Tailscale, which is already on `framework-13` and `home-server`.
This module does not run `tailscale serve`: on `home-server`, :443 is Caddy's.

A new machine still runs the install once. Home-manager does it on activation
when `devswha.ovis` is missing from `plugins.json`. By hand:

```sh
herdr plugin install devswha/ovis --yes
```

`bun` is on the profile. Open http://127.0.0.1:7317. For the phone, once, on
a machine whose Tailscale HTTPS port is free:

```sh
tailscale serve --bg --https=443 http://127.0.0.1:7317
```

Then scan the QR under Settings → Phone & devices. Do not turn on the Ovis
relay.
