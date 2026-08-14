#!/usr/bin/env bash
# Sink whose volume/mute is audible. EasyEffects is a virtual sink; its Pulse
# volume is not applied to the hardware it plays into.

default=$(pactl get-default-sink 2>/dev/null)
[[ -n "$default" ]] || exit 1

case "$default" in
  *easyeffects*) ;;
  *)
    printf '%s\n' "$default"
    exit 0
    ;;
esac

port=$(pw-link -l 2>/dev/null | awk '
  $1 ~ /^ee_soe_output_level:output_/ {
    getline
    if ($1 == "|->") {
      print $2
      exit
    }
  }
')
hw=${port%%:*}

if [[ -n "$hw" ]]; then
  printf '%s\n' "$hw"
  exit 0
fi

speaker_sink=alsa_output.pci-0000_c1_00.6.pro-output-0
if pactl list short sinks | awk '{print $2}' | grep -qx "$speaker_sink"; then
  printf '%s\n' "$speaker_sink"
  exit 0
fi

printf '%s\n' "$default"
