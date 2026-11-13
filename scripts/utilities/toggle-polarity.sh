#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/stylix/polarity"

LIGHT_SWITCH="/nix/var/nix/profiles/system/specialisation/light/bin/switch-to-configuration"
DARK_SWITCH="/nix/var/nix/profiles/system/bin/switch-to-configuration"

LIGHT_MODE_WALLPAPER="$HOME/config/wallpapers/distortion-1-inverted.png"
DARK_MODE_WALLPAPER="$HOME/config/wallpapers/distortion-1.png"

# Prefer the live system over the state file: once you are inside a
# specialisation, /run/current-system/specialisation/ is empty, and the
# state file can drift if a switch fails partway.
current_sys="$(readlink -f /run/current-system)"
light_sys="$(readlink -f /nix/var/nix/profiles/system/specialisation/light 2>/dev/null || true)"
if [ -n "$light_sys" ] && [ "$current_sys" = "$light_sys" ]; then
  current="light"
else
  current="$(tr -d '[:space:]' < "$STATE_FILE" 2>/dev/null || true)"
  if [ -z "$current" ]; then
    current="dark"
  fi
fi

if [ "$current" = "light" ]; then
  target="Dark"
  wallpaper="$DARK_MODE_WALLPAPER"
  switch_bin="$DARK_SWITCH"
else
  target="Light"
  wallpaper="$LIGHT_MODE_WALLPAPER"
  switch_bin="$LIGHT_SWITCH"
fi

# The switch exits non-zero whenever a unit fails, including a partial Home
# Manager activation (e.g. one blocked link). The relinking has already
# happened by then, so never let that abort the UI refresh below.
switch_status=0
sudo "$switch_bin" test || switch_status=$?

# waypaper keeps its own swaybg child, so this replaces the running wallpaper.
waypaper --wallpaper "$wallpaper" || true

hyprctl reload || true

pkill waybar || true
while pgrep waybar >/dev/null 2>&1; do
  sleep 0.05
done
hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("waybar")' || true

if [ "$switch_status" -eq 0 ]; then
  notify-send "🌙 Switched to ${target} Mode"
else
  notify-send -u critical "⚠️ ${target} Mode: Home Manager activation failed" \
    "Run: journalctl -u home-manager-e.service -n 30"
fi
