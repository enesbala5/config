#!/usr/bin/env bash

dir=$(cd "$(dirname "$0")" && pwd)
sink=$("$dir/get_playback_sink.sh")
[[ -n "$sink" ]] || exit 1

case "${1:-}" in
  up) pactl set-sink-volume "$sink" +5% ;;
  down) pactl set-sink-volume "$sink" -5% ;;
  mute) pactl set-sink-mute "$sink" toggle ;;
  *) exit 2 ;;
esac
