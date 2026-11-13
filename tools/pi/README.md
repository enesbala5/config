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
`settings.json`, `keybindings.json`, `AGENTS.md`, `themes/`, and the local
extensions into `~/.pi/agent`. It does **not** touch `auth.json`,
`models-store.json`, `sessions/`, `sidebar-tui.json`, `trust.json`, or
`extensions/herdr-agent-state.ts`: pi and Herdr write those at runtime.

### Default instructions (`AGENTS.md`)

Always-on instructions are written in two places. They are not symlinked to
each other:

| Who | File |
| --- | --- |
| Pi, and any agent that reads `AGENTS.md` | `misc/agents/AGENTS.md`, symlinked to `~/.pi/agent/AGENTS.md` |
| Cursor | `misc/rules/general/<name>.mdc` with `alwaysApply: true`, symlinked via `~/.cursor/rules` |

Pi cannot load `.mdc` (Cursor frontmatter). Cursor does not load
`misc/agents/AGENTS.md`. OpenHands does not need a third edit:
`tools/incus/agent-vm-manage.sh push-rules` copies `misc/rules/**/*.mdc` into
the agent VM.

Change or add an always-on rule in both files in the same edit. Current pairs:

- ADHD: `misc/agents/AGENTS.md` points at the skill; `misc/rules/general/i-have-adhd.mdc` is the Cursor copy.
- Worktrees: `misc/agents/AGENTS.md` ("Git worktrees") and `misc/rules/general/worktrees.mdc`.

Run `/reload` in pi after changing `AGENTS.md`.

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
session from its opening prompt. The prompt's first line is cut to a four-word
label and set as the session name straight away, so the tab never carries the
raw prompt or the static terminal title; then the session's model is asked for
a 2-4 word action-first title, which replaces the label when it arrives. If that
model cannot answer, a cheap model on a configured provider is tried, and if no
model answers the four-word label stays. Every path goes through the same
four-word cut, so a title is never longer than four words whatever the model
returns.

A name set by hand with `/name <text>` or `pi --name <text>` is never
overwritten, and is reported as-is. A seed from an earlier run — including the
raw-prompt titles the previous version left behind — is recognised on reload and
replaced, so a long title does not outlive the update that fixed it.

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
| `Ctrl+/` | Open the model selector (`keybindings.json`) |
| `Ctrl+Shift+/` | Cycle thinking level (`keybindings.json`) |
| `Shift+Tab` | Cycle normal → plan → ask mode (`modes/`) |
| `Ctrl+Alt+P` | Jump to/from plan mode (`modes/`) |
| `Ctrl+Backspace` | Delete a word instead of deleting the session (`keybindings.json`) |

`sidebar-toggle.ts` exists because `pi-sidebar-tui` hardcodes `Ctrl+Shift+T` as
an *extension* shortcut. Extension shortcuts are keyed by their literal key and
`keybindings.json` only checks them for conflicts against built-in actions, so
it cannot remap them. The extension instead reads the sidebar's persisted
`enabled` state and re-dispatches the package's `/sidebar-tui on|off` command,
leaving the package in charge of the toggle logic and compositor lifecycle.

`Ctrl+P` is unbound in the main editor. Kitty encodes `Ctrl+/` and
`Ctrl+Shift+/` separately so Pi can distinguish them from legacy `Ctrl+-`.
Apply changes to `kitty.nix` with Home Manager and reload Kitty's configuration.

## Extensions

- **attach-pasted-images.ts** — previews pasted image paths above the editor and
  turns them into real image attachments on submit.
- **ctrl-p-slash.ts** — shows slash suggestions at word boundaries throughout
  the prompt. Enter runs the highlighted built-in or extension command immediately;
  Tab only inserts its name. Inline execution removes just the command token and
  preserves the surrounding draft, cursor, paste markers and undo. See the behavior
  and checks below.
- **rewind.ts** — `/rewind` picker over user messages; branches the session and
  optionally restores a `git stash create` checkpoint of the worktree.
- **sidebar-toggle.ts** — `Ctrl+Shift+\` toggles the `pi-sidebar-tui` sidebar.
- **modes/** — persistent normal/plan/ask mode system (custom prompts, tool
  restrictions, todo tracking); replaces the standalone plan-mode extension.
- **herdr-agent-state.ts** — *not* in this repo; written by Herdr into
  `~/.pi/agent/extensions/` at runtime. See `tools/herdr/README.md`.

### Slash-command behavior and checks

Type `/mod` and press Enter once to open the native model selector. This works
at the start of the prompt, after draft text, or on a later line. Only the
selected command is dispatched; surrounding text is never sent along with it.
For example, confirming `Explain this /mod` opens the picker and leaves
`Explain this ` ready to continue after selection or cancellation. Whitespace
around the removed token is left unchanged.

Tab inserts `/model ` without executing it, so you can add arguments. Argument
completion retains Pi's native behavior: Enter accepts an argument suggestion;
Enter again submits the completed command. A command at the start of the first
line owns that line's arguments; slash-looking arguments are not reinterpreted
as inline commands. Paths and URLs keep their normal completion behavior.

Skills and prompt templates are insert-only on completion, with either Enter
or Tab. A subsequent explicit submission invokes them normally. Pi only expands
`/skill:name` automatically at the start of a message; inline skill references
are text for the model, not native command expansion.

Session-changing commands (`/new`, `/resume`, `/fork`, `/clone`, `/tree`,
`/import`, `/reload`, `/quit`) retain their native draft-clearing behavior.
Command-controlled non-empty editor replacements are honored. While another
command dispatch is pending, Enter does not start a second dispatch or send the
draft; typing can continue. Reload invalidates the old editor's draft protection.

Run the regression suite from the config repository with Node.js 24 or newer
and Pi installed:

```sh
node --test tools/pi/tests/ctrl-p-slash.test.mjs
```

It uses the installed Pi editor, autocomplete provider, interactive dispatcher,
and selector focus lifecycle, with fake session data and no model requests.
Tests live outside `agent/extensions/` so Pi will not auto-load them. The harness
finds Nix/npm installations automatically; set `PI_NODE_MODULES` to Pi's
`node_modules` directory for another layout. Node may print an experimental
warning for its TypeScript-stripping API.

After changing the extension, run `/reload` in Pi. Check `/mod` → Enter, an inline
`draft /mod` → Enter → Escape, and `draft /mod` → Tab. The first two should open
the picker with one Enter; the inline draft should survive; Tab should only
insert text. `Ctrl+/` should still open the model selector directly.

The editor retains one internal Pi compatibility hook (`tryTriggerAutocomplete`)
for inline triggering. Built-ins are absent from `pi.getCommands()`, so the
extension keeps a built-in allowlist; a test compares it to the installed Pi
release. Rerun the suite after upgrading Pi.

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
