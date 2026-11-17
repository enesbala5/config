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

units=(sunshine-session.service sunshine.service)

failure() {
  printf 'Error: %s\n' "$1" >&2
  systemctl --user status "${units[@]}" --no-pager >&2 || true
  printf '\nRecent Sunshine logs:\n' >&2
  journalctl --user -u "${units[0]}" -u "${units[1]}" -b -n 30 --no-pager >&2 || true
  printf '\nTry: manage-sunshine status / manage-sunshine logs\n' >&2
  return 1
}

wait_for_state() {
  local expected="$1" watcher sunshine attempt
  # The watcher only Wants Sunshine: its start job can succeed even if Sunshine
  # fails. Check both units, allowing a short window for queued startup jobs.
  for ((attempt = 0; attempt < 20; attempt++)); do
    watcher=$(systemctl --user show "${units[0]}" --property=ActiveState --value) || return 1
    sunshine=$(systemctl --user show "${units[1]}" --property=ActiveState --value) || return 1
    if [[ "$watcher" == "$expected" && "$sunshine" == "$expected" ]]; then
      return 0
    fi
    if [[ "$expected" == active && ( "$watcher" == failed || "$sunshine" == failed ) ]]; then
      break
    fi
    sleep 0.25
  done
  printf 'Service states: watcher=%s, sunshine=%s (expected %s).\n' "$watcher" "$sunshine" "$expected" >&2
  return 1
}

start_sunshine() {
  local action="$1" variable
  local -a environment=(WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE)
  if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" || -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf '%s\n' 'Error: no Hyprland session found (WAYLAND_DISPLAY or HYPRLAND_INSTANCE_SIGNATURE is missing).' \
      'Run this command from a terminal inside the laptop Hyprland session.' >&2
    return 1
  fi
  # Direct Hyprland sessions may not export these optional variables. Supply
  # the known session type and import only populated optional values.
  export XDG_SESSION_TYPE=wayland
  environment+=(XDG_SESSION_TYPE)
  for variable in DISPLAY XDG_CURRENT_DESKTOP; do
    [[ -z "${!variable:-}" ]] || environment+=("$variable")
  done
  if [[ "$action" == restart ]]; then
    printf 'Restarting Sunshine and its session watcher...\n'
  else
    printf 'Starting Sunshine and its session watcher...\n'
  fi
  if ! systemctl --user import-environment "${environment[@]}"; then
    failure 'Could not import the Hyprland environment into the user service manager.'
    return 1
  fi
  # Explicitly include Sunshine: starting an already-active watcher alone does
  # not restart a Sunshine process that has stopped or failed independently.
  if ! systemctl --user "$action" "${units[@]}"; then
    failure 'Could not start Sunshine.'
    return 1
  fi
  if ! wait_for_state active; then
    failure 'Sunshine did not become active within 5 seconds.'
    return 1
  fi
  printf '%s\n' 'Sunshine is ON; both services are active.' \
    'Connect with Moonlight. Admin UI: https://localhost:47990' \
    'Use manage-sunshine off when finished.'
}

stop_sunshine() {
  printf 'Stopping Sunshine and its session watcher...\n'
  if ! systemctl --user stop "${units[@]}"; then
    failure 'Could not stop Sunshine.'
    return 1
  fi
  if ! wait_for_state inactive; then
    failure 'Sunshine did not become inactive within 5 seconds.'
    return 1
  fi
  printf '%s\n' 'Sunshine is OFF; both services are stopped. Paired clients are preserved.'
}

if (( $# > 1 )); then
  usage >&2
  exit 2
fi

case "${1:-help}" in
  on) start_sunshine start ;;
  off) stop_sunshine ;;
  status) systemctl --user status sunshine-session.service sunshine.service --no-pager ;;
  restart) start_sunshine restart ;;
  logs)
    printf '%s\n' 'Following Sunshine logs (Ctrl-C exits without stopping Sunshine)...'
    journalctl --user -u sunshine-session.service -u sunshine.service -b -n 100 -f
    ;;
  help|-h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
