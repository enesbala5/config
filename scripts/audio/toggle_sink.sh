#!/usr/bin/env bash

sinks=($(pactl list short sinks | grep -vi "easyeffects" | awk '{print $2}'))
count=${#sinks[@]}
[ "$count" -lt 2 ] && exit 0
current=$(pactl get-default-sink)
idx=0
for i in "${!sinks[@]}"; do
  [[ "${sinks[$i]}" == "$current" ]] && idx=$i && break
done
next="${sinks[$(( (idx + 1) % count ))]}"
pactl set-default-sink "$next"
pactl list short sink-inputs | awk '{print $1}' | \
  xargs -r -I{} pactl move-sink-input {} "$next"
display=$(pactl list sinks | awk "/Name: ${next}/{found=1} found && /Description:/{sub(/.*Description: /, \"\"); print; exit}")
notify-send "🔊 Audio Output" "Switched to: $display" --expire-time=1500
pkill -RTMIN+8 waybar
