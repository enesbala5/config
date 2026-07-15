#!/usr/bin/env bash
# handy-bt-toggle.sh — toggle handy transcription with automatic Bluetooth profile switching.
#
# Bluetooth headsets expose two audio profiles:
#   A2DP  — high-quality stereo playback, no microphone input
#   HSP/HFP — lower-quality mono, but enables the microphone for recording
#
# This script handles the profile swap transparently:
#   Start: pauses music → switches to HSP/HFP → waits for profile to settle → starts handy
#   Stop:  stops handy → switches back to A2DP → resumes music if it was playing
#
# Usage:
#   handy-bt-toggle.sh           toggle recording on/off
#   handy-bt-toggle.sh --cancel  abort an in-progress recording and restore audio
#
# Tune SWITCH_DELAY if the first syllable of a recording is clipped (increase it),
# or if there's a noticeable lag before recording starts (decrease it).

# Supported Bluetooth cards — add/remove entries as needed.
# Names are PipeWire/Pulse card names (MAC with colons → underscores).
BT_CARDS=(
  "bluez_card.00_A4_1C_0C_C8_53"  # WH-CH720N
  "bluez_card.80_9F_F5_71_73_8D"  # Galaxy Buds Live
  "bluez_card.2C_BE_EE_2E_61_E8"  # CMF Buds 2 Plus
)

# Tried in order; first success wins. mSBC is preferred over CVSD.
HSP_PROFILES=(
  "headset-head-unit"       # HSP/HFP mSBC
  "headset-head-unit-cvsd"  # HSP/HFP CVSD fallback
)
A2DP_PROFILES=(
  "a2dp-sink-sbc_xq"
  "a2dp-sink"               # often AAC
  "a2dp-sink-sbc"
)

STATE_FILE="/tmp/handy-bt-recording"
SWITCH_DELAY=0.05                  # seconds to wait for HSP profile to activate
A2DP_RESTORE_DELAY=0.3             # seconds to wait for A2DP sink to reappear

connected_bt_cards() {
  local card available
  available=$(pactl list cards short | awk '{print $2}')
  for card in "${BT_CARDS[@]}"; do
    printf '%s\n' "$available" | grep -qxF "$card" && printf '%s\n' "$card"
  done
}

set_first_working_profile() {
  local card=$1
  shift
  local profile
  for profile in "$@"; do
    if pactl set-card-profile "$card" "$profile" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

switch_to_hsp() {
  local card cards=()
  mapfile -t cards < <(connected_bt_cards)
  ((${#cards[@]})) || return 1
  printf '%s\n' "${cards[@]}" >"${STATE_FILE}.cards"
  for card in "${cards[@]}"; do
    set_first_working_profile "$card" "${HSP_PROFILES[@]}" || return 1
  done
}

switch_to_a2dp() {
  local card cards=()
  if [ -f "${STATE_FILE}.cards" ]; then
    mapfile -t cards <"${STATE_FILE}.cards"
    rm -f "${STATE_FILE}.cards"
  else
    mapfile -t cards < <(connected_bt_cards)
  fi
  for card in "${cards[@]}"; do
    set_first_working_profile "$card" "${A2DP_PROFILES[@]}"
  done
}

restore_audio() {
    switch_to_a2dp
    if [ -f "${STATE_FILE}.playing" ]; then
        rm -f "${STATE_FILE}.playing"
        sleep "$A2DP_RESTORE_DELAY"
        playerctl --ignore-player=kdeconnect play 2>/dev/null
    fi
}

cancel() {
    handy --cancel
    rm -f "$STATE_FILE"
    restore_audio
}

if [ "${1}" = "--cancel" ]; then
    cancel
    exit
fi

if [ -f "$STATE_FILE" ]; then
    handy --toggle-transcription
    rm -f "$STATE_FILE"
    restore_audio
else
    if playerctl --ignore-player=kdeconnect status 2>/dev/null | grep -q "^Playing$"; then
        touch "${STATE_FILE}.playing"
    fi

    touch "$STATE_FILE"
    if ! switch_to_hsp; then
        rm -f "$STATE_FILE" "${STATE_FILE}.playing" "${STATE_FILE}.cards"
        exit 1
    fi
    sleep "$SWITCH_DELAY"
    handy --toggle-transcription
fi
