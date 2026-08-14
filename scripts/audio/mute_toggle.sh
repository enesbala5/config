#!/usr/bin/env bash

dir=$(cd "$(dirname "$0")" && pwd)
"$dir/volume.sh" mute

sink=$("$dir/get_playback_sink.sh")
if pactl get-sink-mute "$sink" | grep -q yes; then
  notify-send "🔇  Muted Audio" --expire-time=1500
else
  notify-send "🔊  Unmuted Audio" --expire-time=1500
fi
