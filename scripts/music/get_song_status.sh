#!/usr/bin/env bash
# One-shot current track for hyprlock (playerctl, any player)

# Active playback device icon (headphones vs speakers)
sink=$(pactl get-default-sink 2>/dev/null)
if [[ "$sink" =~ [Hh]eadphone ]]; then
  icon="🎧 "
else
  icon="🔊 "
fi

out=$(playerctl metadata --format '{{ artist }} - {{ title }}' 2>/dev/null)
if [ -n "$out" ]; then
  status=$(playerctl status 2>/dev/null)
  case "$status" in
    Playing) echo "${icon}Playing · $out" ;;
    Paused)  echo "${icon}Paused · $out" ;;
    *)       echo "${icon}$out" ;;
  esac
else
  echo "🎵 Nothing is playing"
fi
