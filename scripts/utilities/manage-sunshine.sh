#!/usr/bin/env bash
# On-demand Sunshine for the existing Hyprland session.
set -euo pipefail

usage() {
  printf '%s\n' \
    'Usage: manage-sunshine {on|off|status|restart|logs|help}' \
    '  on       Start Sunshine (run inside the laptop Hyprland session).' \
    '  off      Stop Sunshine and its session watcher.' \
    '  status   Show both service states.' \
    '  restart  Restart Sunshine with the current Hyprland environment.' \
    '  logs     Follow both service journals (Ctrl-C to exit).' \
    'Sunshine stays on after Moonlight disconnects; use off when finished.'
}

start_sunshine() {
  if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" || -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf '%s\n' 'Run this command from a terminal inside the laptop Hyprland session.' >&2
    return 1
  fi
  systemctl --user import-environment WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
  systemctl --user "$1" sunshine-session.service
}

if (( $# > 1 )); then
  usage >&2
  exit 2
fi

case "${1:-help}" in
  on) start_sunshine start ;;
  off) systemctl --user stop sunshine-session.service sunshine.service ;;
  status) systemctl --user status sunshine-session.service sunshine.service --no-pager ;;
  restart) start_sunshine restart ;;
  logs) journalctl --user -u sunshine-session.service -u sunshine.service -b -n 100 -f ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
