#!/usr/bin/env bash

# Toggle the mute state of the default audio sink
# I use pipewire-pulse & pulsemixer for audio management
# Use notify-send to show the updated state after toggling

pulsemixer --toggle-mute

mute_status=$(pulsemixer --get-mute)

if [ "$mute_status" -eq 1 ]; then
  status_label="Muted"
	notify-send "🔇  $status_label Audio" --expire-time=1500
else
  status_label="Unmuted"
  notify-send "🔊  $status_label Audio" --expire-time=1500
fi