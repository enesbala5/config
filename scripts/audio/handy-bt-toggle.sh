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

BT_CARD="bluez_card.00_A4_1C_0C_C8_53"
HSP_PROFILE="headset-head-unit"    # mSBC codec — best available HFP quality
A2DP_PROFILE="a2dp-sink-sbc_xq"
STATE_FILE="/tmp/handy-bt-recording"
SWITCH_DELAY=0.05                  # seconds to wait for HSP profile to activate
A2DP_RESTORE_DELAY=0.3             # seconds to wait for A2DP sink to reappear

restore_audio() {
    pactl set-card-profile "$BT_CARD" "$A2DP_PROFILE"
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
    pactl set-card-profile "$BT_CARD" "$HSP_PROFILE"
    sleep "$SWITCH_DELAY"
    handy --toggle-transcription
fi
