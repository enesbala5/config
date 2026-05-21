#!/usr/bin/env bash
DUMMY_FILE="/tmp/light_mode_active"
if [ -f "$DUMMY_FILE" ]; then
  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration test
  rm -f "$DUMMY_FILE"
else
  sudo /run/current-system/specialisation/light/bin/switch-to-configuration test
  touch "$DUMMY_FILE"
fi

hyprctl reload || true
