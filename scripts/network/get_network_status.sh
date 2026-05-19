#!/usr/bin/env bash
# One-shot network connection name for hyprlock (nmcli)

if command -v nmcli &>/dev/null; then
  result=$(nmcli -t -g NAME,TYPE,STATE con show --active 2>/dev/null \
    | awk -F: '($2=="802-11-wireless" || $2=="802-3-ethernet") && $3=="activated" {print $1; exit}')
  if [ -n "$result" ]; then
    echo "$result"
    exit 0
  fi
fi
echo "Not Connected"
