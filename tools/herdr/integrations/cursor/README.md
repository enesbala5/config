# Cursor ↔ Herdr Desktop bridge

Makes Cursor Agent CLI sessions show up in the Herdr Desktop **Agents** sidebar.

## Why

| Client | How it sees Cursor | Works out of the box? |
| --- | --- | --- |
| Herdr TUI (`herdr`) | Screen / process detection + `herdr-agent-state.sh` → `herdr.sock` | Yes |
| Herdr Desktop (`herdr-app` / `hc`) | Only terminals that emit **OSC 7501** | No — Cursor does not send 7501 |

`herdr integration install cursor` installs `~/.cursor/herdr-agent-state.sh`. That script exits unless `HERDR_ENV=1` and `HERDR_SOCKET_PATH` are set. Desktop panes set `HC_TERMINAL_ID` / `HC_TERMINAL_SOCKET` instead, so the stock hook is a no-op there.

Tracked upstream as [herdr-app#98](https://github.com/herdrdev/herdr-app/issues/98) (closed: Cursor must send 7501 natively).

### Why a plain `printf > /dev/tty` is not enough

Cursor runs each hook as a **tty-less child** ([herdr-core#42](https://github.com/herdrdev/herdr-core/issues/42)). Writing OSC 7501 to `/dev/tty` fails, so the pane never sees the report. `hc report` (the proper fix) is not in our `hc` 0.1.18 yet.

This bridge resolves the pane's pts from `hc get $HC_TERMINAL_ID` and writes the OSC there (O_NOCTTY). Fallbacks: `/dev/tty`, then ancestor ttys.

## What this directory is

```
integrations/cursor/
├── desktop-status.sh   # emits OSC 7501 into the pane pts
├── hooks.json          # Cursor hooks: TUI session report + desktop status
└── README.md
```

Home-manager (`modules.home.herdr.desktop.enable`) symlinks:

- `desktop-status.sh` → `~/.cursor/herdr-desktop-status.sh`
- `hooks.json` → `~/.cursor/hooks.json`

`hooks.json` uses absolute `/home/e/...` paths (same style as
`herdr integration install cursor`) so Cursor does not need to expand
`$HOME`. This repo owns `hooks.json` on desktop hosts.
`herdr integration install cursor` may still refresh `herdr-agent-state.sh`;
if it rewrites `hooks.json` through the symlink, restore from git and
re-switch.

## Hook map

| Cursor hook | Bridge state | Meaning |
| --- | --- | --- |
| `sessionStart` | `idle` | Session ready (also runs TUI `herdr-agent-state.sh`) |
| `beforeSubmitPrompt` | `working` | Prompt submitted |
| `postToolUse` | `working` | Still busy after a tool |
| `stop` | `idle` | Turn finished (Herdr shows **done** until you look) |
| `sessionEnd` | `clear` | Session gone |

No `blocked` state: Cursor has no approval-wait hook that only reports without deciding.

`app=cursor` matches herdr-app's programs table (name + icon).

## Verify (~1 minute)

1. Restart a Cursor tab in Herdr Desktop (hooks are read at `cursor-agent` start).
2. Send a short prompt.
3. Check:

```sh
hc get <terminal>          # reported: true, status.app: cursor
herdr-app ls               # that terminal's status/app populated
```

The Agents sidebar should list it as working → idle/done.

Manual inject (proves delivery path without waiting on hooks):

```sh
pid=$(hc get t14 | sed -n 's/.*"pid":\([0-9]*\).*/\1/p')
printf '\033]7501;state=idle:app=cursor\033\\' > "$(readlink /proc/$pid/fd/1)"
```

## Limits

- Only Cursor. Pi / Claude that speak OSC 7501 already appear; other agents need their own bridge.
- TUI and Desktop still do not share sessions — this only fixes detection inside Desktop panes.
- Needs `hc` on PATH inside the hook environment.
- Native OSC 7501 in Cursor CLI, or `hc report` in a newer core, would make this bridge unnecessary.
