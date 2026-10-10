# Pi

Config for [pi](https://github.com/earendil-works/pi), the coding agent. This
directory is the version-controlled source of truth for the parts of
`~/.pi/agent` that are worth keeping; everything else there is runtime state.

## Layout

```text
tools/pi/agent/
├── settings.json                   # ~/.pi/agent/settings.json (symlinked)
├── keybindings.json                # ~/.pi/agent/keybindings.json (symlinked)
├── themes/                         # ~/.pi/agent/themes (symlinked, recursive)
│   ├── circus.json
│   └── circus-light.json
└── extensions/
    ├── attach-pasted-images.ts     # symlinked
    ├── ctrl-p-slash.ts             # symlinked
    ├── herdr-pi-title.ts           # symlinked; pi title -> Herdr pane title
    ├── rewind.ts                   # symlinked
    ├── sidebar-toggle.ts           # symlinked
    └── modes/                      # symlinked, recursive
```

Home-manager (`nix/nixos/hosts/framework-13/home/default.nix`) symlinks
`settings.json`, `keybindings.json`, `themes/`, and the local extensions
into `~/.pi/agent`. It does **not** touch `auth.json`, `models-store.json`,
`sessions/`, `sidebar-tui.json`, `trust.json`, or `extensions/herdr-agent-state.ts`:
pi and Herdr write those at runtime.

### Herdr tab titles

`herdr-pi-title.ts` reports the pi session name to Herdr as the pane's agent
*title* (`pane.report_metadata`), which is the source Herdr's Auto Title plugin
ranks highest when naming tabs. Herdr's own pi integration
(`herdr-agent-state.ts`, owned and overwritten by `herdr integration install pi`)
reports state and session but never a title, which is why pi tabs otherwise fall
back to the static `π - <dir>` terminal title. The hook lives in a separate file
so an integration update cannot remove it, and reports with a TTL so a dead pi
stops naming its tab.

pi has no auto-titling of its own, so the extension also names an unnamed
session from its opening prompt: it asks the active model for a short,
action-first title (a tighter 3-5 word one than `pi-sidebar-tui` asks for its
panel, since a tab is narrower) and sets that as the session name. If the model is slow or fails, the
prompt itself is summarised instead, so Auto Title always gets something. A name
set by hand with `/name <text>` or `pi --name <text>` is never overwritten, and
is reported as-is. A seed from an earlier run is recognised on reload and
generated again, so a raw-prompt title does not outlive the update that set it.

The `pi` binary itself comes from the `pi` flake input
(`github:earendil-works/pi/stable`) and is added to `home.packages` in
`nix/nixos/hosts/framework-13/home/programs/default.nix`, so it needs no manual
install.

## New-machine setup

Only credentials and the npm packages need a first run; the config files
arrive with `home-manager switch`.

### Packages

The npm packages are declared in `settings.json` under `packages`:

```text
@ogulcancelik/pi-minimal-footer   # minimal statusline
pi-sidebar-tui                    # OpenCode-style sidebar panel
```

Pi installs missing declared packages automatically on first launch (network +
`npm` from PATH). To reconcile or reinstall by hand:

```sh
pi install npm:@ogulcancelik/pi-minimal-footer
pi install npm:pi-sidebar-tui

pi list          # verify both are present
```

Prerequisites on the machine: `node` and `npm` (both provided by the Playwright
home module, which is enabled on framework-13).

### Credentials

`settings.json` defaults to `deepseek` / `deepseek-flash`. Auth lives in the
unmanaged `~/.pi/agent/auth.json`, so a fresh machine must sign in once:

```sh
pi              # then run:
/login deepseek
```

Paste the key from the agenix secret `deepseek-api-key`, or export
`DEEPSEEK_API_KEY` before launching pi instead. Verify with:

```sh
pi auth check --provider deepseek
```

## Keyboard shortcuts

| Key | Action |
| --- | --- |
| `Ctrl+Shift+\` | Toggle the sidebar (`sidebar-toggle.ts`) |
| `Ctrl+Shift+T` | Toggle the sidebar (built into `pi-sidebar-tui`) |
| `Ctrl+P` | Insert `/` to open the slash-command menu (`ctrl-p-slash.ts`) |
| `Shift+Tab` | Cycle normal → plan → ask mode (`modes/`) |
| `Ctrl+Alt+P` | Jump to/from plan mode (`modes/`) |
| `Ctrl+Backspace` | Delete a word instead of deleting the session (`keybindings.json`) |

`sidebar-toggle.ts` exists because `pi-sidebar-tui` hardcodes `Ctrl+Shift+T` as
an *extension* shortcut. Extension shortcuts are keyed by their literal key and
`keybindings.json` only checks them for conflicts against built-in actions, so
it cannot remap them. The extension instead reads the sidebar's persisted
`enabled` state and re-dispatches the package's `/sidebar-tui on|off` command,
leaving the package in charge of the toggle logic and compositor lifecycle.

Some `keybindings.json` entries deliberately clear pi defaults — for example
`app.model.cycleForward` is unbound so `ctrl-p-slash.ts` can own `Ctrl+P`.

## Extensions

- **attach-pasted-images.ts** — previews pasted image paths above the editor and
  turns them into real image attachments on submit.
- **ctrl-p-slash.ts** — `Ctrl+P` inserts `/` (slash-command helper) instead of
  cycling models.
- **rewind.ts** — `/rewind` picker over user messages; branches the session and
  optionally restores a `git stash create` checkpoint of the worktree.
- **sidebar-toggle.ts** — `Ctrl+Shift+\` toggles the `pi-sidebar-tui` sidebar.
- **modes/** — persistent normal/plan/ask mode system (custom prompts, tool
  restrictions, todo tracking); replaces the standalone plan-mode extension.
- **herdr-agent-state.ts** — *not* in this repo; written by Herdr into
  `~/.pi/agent/extensions/` at runtime. See `tools/herdr/README.md`.

## Runtime state (not versioned)

| Path | Written by | Notes |
| --- | --- | --- |
| `auth.json` | pi `/login` | Provider credentials |
| `models-store.json` | pi | HTTP model-catalog cache |
| `sessions/` | pi | Conversation history |
| `sidebar-tui.json` | `pi-sidebar-tui` | Sidebar `enabled` / width / panel sizes |
| `trust.json` | pi | Project-trust decisions |
| `extensions/herdr-agent-state.ts` | Herdr | Herdr's state widget |
| `npm/` | `pi install` | Managed npm package tree |
