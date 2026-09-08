#!/usr/bin/env bash

# Global Do Not Disturb toggle via dunst.
# Usage:
#   dnd-toggle.sh            → toggle DND on/off
#   dnd-toggle.sh on         → enable DND (silence notifications)
#   dnd-toggle.sh off        → disable DND (restore notifications)
#   dnd-toggle.sh status     → emit JSON for the waybar indicator (signal 10)

WAYBAR_SIGNAL=10

refresh_waybar() {
	pkill -RTMIN+"$WAYBAR_SIGNAL" waybar 2>/dev/null || true
}

is_dnd_on() {
	local level
	level=$(dunstctl get-pause-level 2>/dev/null || echo 0)
	[[ "$level" -gt 0 ]]
}

emit_status() {
	# Hide while screen recording is active (it handles DND itself).
	if pgrep -x wl-screenrec >/dev/null; then
		printf '{"text":"","class":"idle","tooltip":""}\n'
		return 0
	fi
	if is_dnd_on; then
		printf '{"text":"[DND]","class":"dnd-on","tooltip":"Do Not Disturb: ON"}\n'
	else
		printf '{"text":"","class":"dnd-off","tooltip":"Do Not Disturb: OFF"}\n'
	fi
}

enable_dnd() {
	dunstctl close-all >/dev/null 2>&1 || true
	dunstctl set-paused true >/dev/null 2>&1 || true
	refresh_waybar
}

disable_dnd() {
	dunstctl set-paused false >/dev/null 2>&1 || true
	refresh_waybar
}

toggle_dnd() {
	if is_dnd_on; then
		disable_dnd
	else
		enable_dnd
	fi
}

case "${1:-toggle}" in
	status) emit_status ;;
	on)     enable_dnd ;;
	off)    disable_dnd ;;
	toggle) toggle_dnd ;;
	*)      toggle_dnd ;;
esac
