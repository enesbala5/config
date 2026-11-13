#!/usr/bin/env bash
# Report Cursor Agent CLI state to herdr-core (Herdr Desktop) via OSC 7501.
#
# Desktop Agents panel only lists terminals that emit OSC 7501. Cursor does not
# send it natively. The TUI integration (~/.cursor/herdr-agent-state.sh) talks
# to herdr.sock when HERDR_ENV=1 and never runs in desktop panes (those set
# HC_TERMINAL_ID instead).
#
# Cursor runs each hook as a tty-less child, so `printf > /dev/tty` fails
# (herdr-core#42). Delivery order:
#   1. the pane's pts from `hc get $HC_TERMINAL_ID` (reliable, no tty needed)
#   2. /dev/tty if the hook somehow has a controlling terminal
#   3. ancestor process ttys (juliorr/herdr-cursor-status approach)
#
# Usage: desktop-status.sh <idle|working|clear|error>
# Wired from hooks.json. No-op outside Herdr Desktop.
#
# Upstream: https://github.com/herdrdev/herdr-app/issues/98

state="${1:-}"
case "$state" in
  idle | working | clear | error) ;;
  *) exit 0 ;;
esac

# Desktop panes only. Leave TUI / plain terminals alone.
[ -n "${HC_TERMINAL_ID:-}" ] || exit 0

# app=cursor is herdr-app's programs-table key (name + icon).
osc=$(printf '\033]7501;state=%s:app=cursor\033\\' "$state")

emit() {
  local path="$1"
  [ -n "$path" ] || return 1
  # O_NOCTTY: opening the pane pts must not steal its controlling terminal.
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import os, sys
path, data = sys.argv[1], sys.argv[2].encode()
flags = os.O_WRONLY | getattr(os, "O_NOCTTY", 0)
fd = os.open(path, flags)
try:
    os.write(fd, data)
finally:
    os.close(fd)
' "$path" "$osc" 2>/dev/null
  else
    printf '%s' "$osc" > "$path" 2>/dev/null
  fi
}

# 1) Pane pts via herdr-core (hook has HC_TERMINAL_ID, no tty required).
if command -v hc >/dev/null 2>&1; then
  pid=$(hc get "$HC_TERMINAL_ID" 2>/dev/null | sed -n 's/.*"pid":\([0-9][0-9]*\).*/\1/p' | head -1)
  if [ -n "$pid" ]; then
    if [ -e "/proc/$pid/fd/1" ]; then
      tty_path=$(readlink "/proc/$pid/fd/1" 2>/dev/null || true)
      case "$tty_path" in
        /dev/pts/* | /dev/tty*) emit "$tty_path" && exit 0 ;;
      esac
    fi
    tty_name=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    case "$tty_name" in
      "?" | "") ;;
      /*) emit "$tty_name" && exit 0 ;;
      *) emit "/dev/$tty_name" && exit 0 ;;
    esac
  fi
fi

# 2) Controlling terminal, if any.
emit /dev/tty && exit 0

# 3) Walk ancestors for a pts (hook may still share the agent's session).
pid=$$
i=0
while [ "$i" -lt 8 ]; do
  i=$((i + 1))
  ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  [ -n "$ppid" ] && [ "$ppid" -gt 1 ] 2>/dev/null || break
  pid=$ppid
  tty_name=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  case "$tty_name" in
    "?" | "") continue ;;
    /*) emit "$tty_name" && exit 0 ;;
    *) emit "/dev/$tty_name" && exit 0 ;;
  esac
done

exit 0
