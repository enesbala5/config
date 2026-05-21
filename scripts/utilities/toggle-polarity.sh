#!/usr/bin/env bash

DUMMY_FILE="/tmp/light_mode_active"

LIGHT_MODE_WALLPAPER="~/config/wallpapers/distortion-1-inverted.png"
DARK_MODE_WALLPAPER="~/config/wallpapers/distortion-1.png"

if [ -f "$DUMMY_FILE" ]; then
  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration test
  waypaper --wallpaper "$DARK_MODE_WALLPAPER"
  notify-send "🌙 Switched to Dark Mode"
  rm -f "$DUMMY_FILE"
else
  sudo /run/current-system/specialisation/light/bin/switch-to-configuration test
  waypaper --wallpaper "$LIGHT_MODE_WALLPAPER"
  notify-send "☀️ Switched to Light Mode"
  touch "$DUMMY_FILE"
fi

hyprctl reload || true
