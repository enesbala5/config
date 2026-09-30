#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/stylix/polarity"

LIGHT_SWITCH="/nix/var/nix/profiles/system/specialisation/light/bin/switch-to-configuration"
DARK_SWITCH="/nix/var/nix/profiles/system/bin/switch-to-configuration"

LIGHT_MODE_WALLPAPER="~/config/wallpapers/distortion-1-inverted.png"
DARK_MODE_WALLPAPER="~/config/wallpapers/distortion-1.png"

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
  sudo "$DARK_SWITCH" test
  waypaper --wallpaper "$DARK_MODE_WALLPAPER"
  notify-send "🌙 Switched to Dark Mode"
else
  sudo "$LIGHT_SWITCH" test
  waypaper --wallpaper "$LIGHT_MODE_WALLPAPER"
  notify-send "☀️ Switched to Light Mode"
fi

hyprctl reload || true
pkill -9 waybar || true
while pgrep waybar >/dev/null 2>&1; do
  sleep 0.05
done
hyprctl --instance 0 dispatch exec waybar || true
