#!/usr/bin/env bash

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/stylix/polarity"

LIGHT_MODE_WALLPAPER="~/config/wallpapers/distortion-1-inverted.png"
DARK_MODE_WALLPAPER="~/config/wallpapers/distortion-1.png"

current="$(tr -d '[:space:]' < "$STATE_FILE" 2>/dev/null || true)"
if [ -z "$current" ]; then
  current="dark"
fi

if [ "$current" = "light" ]; then
  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration test
  waypaper --wallpaper "$DARK_MODE_WALLPAPER"
  notify-send "🌙 Switched to Dark Mode"
else
  sudo /run/current-system/specialisation/light/bin/switch-to-configuration test
  waypaper --wallpaper "$LIGHT_MODE_WALLPAPER"
  notify-send "☀️ Switched to Light Mode"
fi

hyprctl reload || true
pkill -9 waybar || true
while pgrep waybar >/dev/null 2>&1; do
  sleep 0.05
done
hyprctl --instance 0 dispatch exec waybar || true
