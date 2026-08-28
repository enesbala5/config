#!/usr/bin/env bash
# handy-bt-toggle.sh — toggle handy transcription with automatic Bluetooth profile switching.
#
# Bluetooth headsets expose two audio profiles:
#   A2DP  — high-quality stereo playback, no microphone input
#   HSP/HFP — lower-quality mono, but enables the microphone for recording
#
# Handy is started on demand (no autostart). First shortcut launches it hidden.
# After recording stops or is cancelled, Handy exits after IDLE_TIMEOUT seconds.
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
IDLE_PID_FILE="/tmp/handy-bt-idle.pid"
SWITCH_DELAY=0.05                  # seconds to wait for HSP profile to activate
A2DP_RESTORE_DELAY=0.3             # seconds to wait for A2DP sink to reappear
HANDY_START_TIMEOUT=15             # seconds to wait for Handy to become ready
IDLE_TIMEOUT=240                   # quit Handy after this many idle seconds

handy_running() {
    pgrep -x handy >/dev/null 2>&1 && return 0
    # Nix wraps the binary; comm is ".handy-wrapped" instead of "handy".
    pgrep -x '.handy-wrapped' >/dev/null 2>&1
}

cancel_idle_quit() {
    local pid
    [ -f "$IDLE_PID_FILE" ] || return 0
    pid=$(cat "$IDLE_PID_FILE")
    rm -f "$IDLE_PID_FILE"
    [ -n "$pid" ] || return 0
    kill "$pid" 2>/dev/null
    pkill -P "$pid" 2>/dev/null
}

schedule_idle_quit() {
    cancel_idle_quit
    (
        sleep "$IDLE_TIMEOUT"
        rm -f "$IDLE_PID_FILE"
        [ -f "$STATE_FILE" ] && exit 0
        handy_running || exit 0
        pkill -x handy 2>/dev/null
        pkill -x '.handy-wrapped' 2>/dev/null
    ) &
    echo $! >"$IDLE_PID_FILE"
    disown $! 2>/dev/null || disown
}

notify() {
    local message=$1
    local urgency=${2:-normal}
    local icon=${3:-audio-input-microphone}
    notify-send \
        --app-name=Handy \
        --expire-time=2500 \
        --urgency="$urgency" \
        --icon="$icon" \
        --hint=string:frcolor:#F8A1C9 \
        --hint=string:hlcolor:#F8A1C9 \
        "Handy" "$message"
}

ensure_handy_running() {
    handy_running && return 0

    notify "Starting Handy"

    handy --start-hidden >/dev/null 2>&1 &
    disown $! 2>/dev/null || disown

    local i
    for i in $(seq 1 $((HANDY_START_TIMEOUT * 5))); do
        if handy_running; then
            sleep 1
            return 0
        fi
        sleep 0.2
    done

    notify "Handy failed to start" critical dialog-error
    return 1
}

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
  # No listed headset connected — use the default mic and still start recording.
  ((${#cards[@]})) || return 0
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
    "$(dirname "$0")/hypr-piper-speak.sh" stop
    handy_running && handy --cancel
    rm -f "$STATE_FILE"
    restore_audio
    schedule_idle_quit
}

if [ "${1}" = "--cancel" ]; then
    cancel
    exit
fi

if [ -f "$STATE_FILE" ]; then
    handy_running && handy --toggle-transcription

    rm -f "$STATE_FILE"

    restore_audio
    schedule_idle_quit
else
    cancel_idle_quit
    ensure_handy_running || {
        schedule_idle_quit
        exit 1
    }

    if playerctl --ignore-player=kdeconnect status 2>/dev/null | grep -q "^Playing$"; then
        touch "${STATE_FILE}.playing"
    fi

    touch "$STATE_FILE"
    if ! switch_to_hsp; then
        rm -f "$STATE_FILE" "${STATE_FILE}.playing" "${STATE_FILE}.cards"
        notify "Couldn't switch headset to call mode" critical dialog-error
        schedule_idle_quit
        exit 1
    fi
    sleep "$SWITCH_DELAY"
    handy --toggle-transcription
fi
