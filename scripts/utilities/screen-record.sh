#!/usr/bin/env bash

# Record a screen region with wl-screenrec + slurp.
# Re-run to stop an active recording.
# `status` prints JSON for the waybar indicator (signal 9).
# Saves to ~/misc/media/Screen Recordings/

DEST_DIR="$HOME/misc/media/Screen Recordings"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/screen-record"
START_FILE="$STATE_DIR/started_at"
OUTPUT_FILE="$STATE_DIR/output"
PAUSE_FILE="$STATE_DIR/dunst_pause_level"
WAYBAR_SIGNAL=9
SOUNDS="/run/current-system/sw/share/sounds/freedesktop/stereo"

play_sound() {
	local file="$SOUNDS/$1"
	[[ -f "$file" ]] || return 0
	pw-play "$file" >/dev/null 2>&1 &
}

refresh_waybar() {
	pkill -RTMIN+"$WAYBAR_SIGNAL" waybar 2>/dev/null || true
}

pause_notifications() {
	mkdir -p "$STATE_DIR"
	dunstctl get-pause-level >"$PAUSE_FILE" 2>/dev/null || echo 0 >"$PAUSE_FILE"
	dunstctl close-all >/dev/null 2>&1 || true
	dunstctl set-paused true >/dev/null 2>&1 || true
}

restore_notifications() {
	local level=0
	[[ -f "$PAUSE_FILE" ]] && level=$(cat "$PAUSE_FILE")
	dunstctl set-pause-level "$level" >/dev/null 2>&1 || dunstctl set-paused false >/dev/null 2>&1 || true
}

format_duration() {
	local s=$1
	local h=$((s / 3600))
	local m=$(((s % 3600) / 60))
	local sec=$((s % 60))
	if ((h > 0)); then
		printf '%d:%02d:%02d' "$h" "$m" "$sec"
	else
		printf '%d:%02d' "$m" "$sec"
	fi
}

emit_status() {
	if ! pgrep -x wl-screenrec >/dev/null; then
		if [[ -f "$START_FILE" ]]; then
			restore_notifications
			rm -rf "$STATE_DIR"
		fi
		printf '{"text":"","class":"idle","tooltip":""}\n'
		return 0
	fi

	local started now elapsed tooltip
	started=$(cat "$START_FILE" 2>/dev/null || true)
	if [[ -n "$started" ]]; then
		now=$(date +%s)
		elapsed=$((now - started))
		((elapsed < 0)) && elapsed=0
		tooltip="Recording $(format_duration "$elapsed")"
	else
		tooltip="Recording"
	fi
	printf '{"text":"●","class":"recording","tooltip":"%s"}\n' "$tooltip"
}

stop_recording() {
	local output
	output=$(cat "$OUTPUT_FILE" 2>/dev/null || true)

	pkill -SIGINT wl-screenrec
	local i
	for i in $(seq 1 40); do
		pgrep -x wl-screenrec >/dev/null || break
		sleep 0.05
	done
	restore_notifications
	rm -rf "$STATE_DIR"
	refresh_waybar
	play_sound complete.oga
	if [[ -n "$output" ]]; then
		printf '%s' "$output" | wl-copy
		notify-send "Screen recording stopped" "Path copied to clipboard"
	else
		notify-send "Screen recording stopped" "Saved to $DEST_DIR"
	fi
	exit 0
}

start_recording() {
	mkdir -p "$DEST_DIR"
	local filename selection return_code
	filename="$DEST_DIR/$(date +'%Y-%m-%d-%H%M%S').mp4"

	selection=$(slurp 2>/dev/null)
	return_code=$?
	if [ "$return_code" -ne 0 ] || [ -z "$selection" ]; then
		notify-send "Screen recording cancelled" "No area selected"
		exit 1
	fi

	pause_notifications
	wl-screenrec -g "$selection" -f "$filename" &

	local i
	for i in $(seq 1 25); do
		pgrep -x wl-screenrec >/dev/null && break
		sleep 0.04
	done
	if ! pgrep -x wl-screenrec >/dev/null; then
		restore_notifications
		rm -rf "$STATE_DIR"
		notify-send "Screen recording failed" "wl-screenrec did not start"
		exit 1
	fi

	date +%s >"$START_FILE"
	printf '%s' "$filename" >"$OUTPUT_FILE"
	refresh_waybar
	play_sound message-new-instant.oga
}

if [[ "${1:-}" == "status" ]]; then
	emit_status
	exit 0
fi

if pgrep -x wl-screenrec >/dev/null; then
	stop_recording
fi

start_recording
