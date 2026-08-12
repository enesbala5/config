#!/usr/bin/env bash

# Record a screen region with wl-screenrec + slurp.
# Re-run to stop an active recording.
# Saves to ~/misc/media/Screen Recordings/

DEST_DIR="$HOME/misc/media/Screen Recordings"

if pgrep -x wl-screenrec >/dev/null; then
	pkill -SIGINT wl-screenrec
	notify-send "Screen recording stopped" "Saved to $DEST_DIR"
	exit 0
fi

mkdir -p "$DEST_DIR"
FILENAME="$DEST_DIR/$(date +'%Y-%m-%d-%H%M%S').mp4"

SELECTION=$(slurp 2>/dev/null)
RETURN_CODE=$?

if [ $RETURN_CODE -ne 0 ] || [ -z "$SELECTION" ]; then
	notify-send "Screen recording cancelled" "No area selected"
	exit 1
fi

wl-screenrec -g "$SELECTION" -f "$FILENAME" &

notify-send "Screen recording started" "Saving to $FILENAME"
