#!/usr/bin/env bash

# Record a screen region with wl-screenrec + slurp.
# Re-run to stop an active recording (keeps the file).
# `cancel` / `--cancel` aborts and discards the file.
# `status` prints JSON for the waybar indicator (signal 9).
# Saves to ~/misc/media/Screen Recordings/
# Last wl-screenrec log: ~/.local/state/screen-record/last.log

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$HOME/misc/media/Screen Recordings"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/screen-record"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/screen-record"
LOG_FILE="$LOG_DIR/last.log"
START_FILE="$STATE_DIR/started_at"
OUTPUT_FILE="$STATE_DIR/output"
PAUSE_FILE="$STATE_DIR/dnd_was_active"
WAYBAR_SIGNAL=9
DND_WAYBAR_SIGNAL=10
SOUNDS="/run/current-system/sw/share/sounds/freedesktop/stereo"

play_sound() {
	local file="$SOUNDS/$1"
	[[ -f "$file" ]] || return 0
	pw-play "$file" >/dev/null 2>&1 &
}

refresh_waybar() {
	pkill -RTMIN+"$WAYBAR_SIGNAL" waybar 2>/dev/null || true
	pkill -RTMIN+"$DND_WAYBAR_SIGNAL" waybar 2>/dev/null || true
}

pause_notifications() {
	mkdir -p "$STATE_DIR"
	# Save pre-recording DND state so restore_notifications knows whether to undo it.
	dunstctl is-paused >"$PAUSE_FILE" 2>/dev/null || echo "false" >"$PAUSE_FILE"
	"$SCRIPT_DIR/dnd-toggle.sh" on
}

restore_notifications() {
	local was_paused="false"
	[[ -f "$PAUSE_FILE" ]] && was_paused=$(cat "$PAUSE_FILE")
	# Only disable DND if it was off before recording started.
	if [[ "$was_paused" != "true" ]]; then
		"$SCRIPT_DIR/dnd-toggle.sh" off
	fi
}

# Failure toasts must be visible even if DND is still on (or was already on).
notify_visible() {
	local title=$1 body=$2
	local was_paused
	was_paused=$(dunstctl is-paused 2>/dev/null || echo false)
	dunstctl set-paused false >/dev/null 2>&1 || true
	notify-send -u critical "$title" "$body"
	if [[ "$was_paused" == "true" ]]; then
		dunstctl set-paused true >/dev/null 2>&1 || true
	fi
}

recording_error() {
	local line=""
	if [[ -f "$LOG_FILE" ]]; then
		line=$(grep -iE 'bailing|failed|error|no such|cannot' "$LOG_FILE" | grep -vi low_power | tail -1)
		[[ -z "$line" ]] && line=$(tail -1 "$LOG_FILE")
	fi
	printf '%s' "${line:-wl-screenrec exited}"
}

# slurp often overshoots a full-monitor drag by 1px; wl-screenrec then bails.
# Snap to the output if the selection covers it (2px slop), otherwise intersect.
clamp_selection() {
	local geom=$1
	local x y w h clamped
	if [[ ! "$geom" =~ ^(-?[0-9]+),(-?[0-9]+)[[:space:]]+([0-9]+)x([0-9]+)$ ]]; then
		printf '%s' "$geom"
		return 0
	fi
	x=${BASH_REMATCH[1]}
	y=${BASH_REMATCH[2]}
	w=${BASH_REMATCH[3]}
	h=${BASH_REMATCH[4]}

	clamped=$(hyprctl -j monitors 2>/dev/null | jq -r --arg sx "$x" --arg sy "$y" --arg sw "$w" --arg sh "$h" '
		def overlap(ax; ay; aw; ah; bx; by; bw; bh):
			([ax, bx] | max) as $ix
			| ([ay, by] | max) as $iy
			| ([ax+aw, bx+bw] | min) as $ix2
			| ([ay+ah, by+bh] | min) as $iy2
			| ([$ix2 - $ix, 0] | max) * ([$iy2 - $iy, 0] | max);
		($sx | tonumber) as $sx | ($sy | tonumber) as $sy
		| ($sw | tonumber) as $sw | ($sh | tonumber) as $sh
		| (map(select(.disabled | not))
			| map(. + {ov: overlap($sx; $sy; $sw; $sh; .x; .y; .width; .height)})
			| max_by(.ov)) as $m
		| if ($m | type) == "null" or $m.ov <= 0 then empty
			else
				2 as $slop
				| if ($sx <= $m.x + $slop)
						and ($sy <= $m.y + $slop)
						and ($sx+$sw >= $m.x+$m.width - $slop)
						and ($sy+$sh >= $m.y+$m.height - $slop)
					then "\($m.x),\($m.y) \($m.width)x\($m.height)"
					else
						([$sx, $m.x] | max) as $cx
						| ([$sy, $m.y] | max) as $cy
						| ([$sx+$sw, $m.x+$m.width] | min) as $cx2
						| ([$sy+$sh, $m.y+$m.height] | min) as $cy2
						| if ($cx2 - $cx) < 1 or ($cy2 - $cy) < 1 then empty
							else "\($cx),\($cy) \($cx2-$cx)x\($cy2-$cy)"
							end
					end
			end
	') || true

	if [[ -z "$clamped" ]]; then
		return 1
	fi
	printf '%s' "$clamped"
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
			notify_visible "Screen recording failed" "$(recording_error)"
			rm -rf "$STATE_DIR"
			refresh_waybar
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

recording_active() {
	pgrep -x wl-screenrec >/dev/null || [[ -f "$START_FILE" ]]
}

kill_recorder() {
	local sig=${1:-INT}
	pkill -"$sig" wl-screenrec 2>/dev/null || true
	local i
	for i in $(seq 1 40); do
		pgrep -x wl-screenrec >/dev/null || return 0
		sleep 0.05
	done
	pkill -KILL wl-screenrec 2>/dev/null || true
}

cleanup_state() {
	restore_notifications
	rm -rf "$STATE_DIR"
	refresh_waybar
}

stop_recording() {
	local output
	output=$(cat "$OUTPUT_FILE" 2>/dev/null || true)

	# Drop START_FILE first so waybar status does not treat this as a crash.
	rm -f "$START_FILE"
	kill_recorder INT
	cleanup_state
	play_sound complete.oga
	if [[ -n "$output" ]]; then
		printf '%s' "$output" | wl-copy
		notify-send "Screen recording stopped" "Path copied to clipboard"
	else
		notify-send "Screen recording stopped" "Saved to $DEST_DIR"
	fi
	exit 0
}

cancel_recording() {
	local output
	output=$(cat "$OUTPUT_FILE" 2>/dev/null || true)

	rm -f "$START_FILE"
	kill_recorder TERM
	[[ -n "$output" ]] && rm -f "$output"
	cleanup_state
	notify-send "Screen recording cancelled" "Discarded"
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
	if ! selection=$(clamp_selection "$selection"); then
		notify_visible "Screen recording failed" "Selection is not on a display"
		exit 1
	fi

	# Prefer the desktop audio monitor (system sounds + apps); fall back to default source.
	local audio_device
	audio_device=$(pactl get-default-sink 2>/dev/null)
	if [[ -n "$audio_device" ]]; then
		audio_device="${audio_device}.monitor"
	fi

	mkdir -p "$LOG_DIR" "$STATE_DIR"
	: >"$LOG_FILE"
	# Wait until the encoder is actually up before silencing notifications.
	# Region/encoder errors exit immediately; a brief pgrep would miss them.
	wl-screenrec -g "$selection" -f "$filename" --audio ${audio_device:+--audio-device "$audio_device"} \
		>"$LOG_FILE" 2>&1 &

	local i
	for i in $(seq 1 20); do
		if ! pgrep -x wl-screenrec >/dev/null; then
			[[ -f "$filename" && ! -s "$filename" ]] && rm -f "$filename"
			rm -rf "$STATE_DIR"
			notify_visible "Screen recording failed" "$(recording_error)"
			exit 1
		fi
		sleep 0.05
	done

	pause_notifications
	date +%s >"$START_FILE"
	printf '%s' "$filename" >"$OUTPUT_FILE"
	refresh_waybar
	play_sound message-new-instant.oga
}

if [[ "${1:-}" == "status" ]]; then
	emit_status
	exit 0
fi

if [[ "${1:-}" == "cancel" || "${1:-}" == "--cancel" ]]; then
	recording_active && cancel_recording
	exit 0
fi

if pgrep -x wl-screenrec >/dev/null; then
	stop_recording
fi

start_recording
