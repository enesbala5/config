#!/usr/bin/env bash
# One-shot battery percentage for hyprlock (supports BAT0 or BAT1)

for bat in /sys/class/power_supply/BAT*/capacity; do
  [ -f "$bat" ] || continue
  pct=$(cat "$bat" 2>/dev/null)
  [ -n "$pct" ] || continue
  status_file="${bat%capacity}status"
  status=""
  [ -f "$status_file" ] && status=$(cat "$status_file" 2>/dev/null)
  if [ "$status" = "Charging" ]; then
    echo "${pct}% ↑"
  else
    echo "${pct}%"
  fi
  exit 0
done
echo "—"
