#!/usr/bin/env bash

# Take a screenshot using grim and slurp
# Save it to the user's pictures directory only if valid
# Copy the path, then the image, as two clipboard entries
# Notify the user

FILENAME="$HOME/gdrive/Media/Screenshots/$(date +'%Y-%m-%d-%H%M%S.png')"
TEMP_FILE="/tmp/screenshot_temp_$(openssl rand -hex 8).png"

# Get the selection area
SELECTION=$(slurp 2>/dev/null)
RETURN_CODE=$?

# Check if selection was made
if [ $RETURN_CODE -ne 0 ] || [ -z "$SELECTION" ]; then
    notify-send "Screenshot failed" "No area selected"
    exit 1
fi

# Take the screenshot with the selection
grim -g "$SELECTION" - > "$TEMP_FILE"

# Check if screenshot was captured successfully
if [ -s "$TEMP_FILE" ]; then
    mv "$TEMP_FILE" "$FILENAME"
    # Path first, image second. Vicinae timestamps history in whole seconds,
    # so wait until the path is stored and the clock ticks before the image
    # copy. Otherwise the two entries sort in either order.
    printf '%s' "$FILENAME" | wl-copy --type text/plain
    clipboard_db="${XDG_DATA_HOME:-$HOME/.local/share}/vicinae/clipboard.db"
    sql_path=${FILENAME//\'/\'\'}
    deadline=$((SECONDS + 2))
    if [ -f "$clipboard_db" ] && command -v sqlite3 >/dev/null 2>&1; then
        while [ "$SECONDS" -lt "$deadline" ]; do
            if sqlite3 "file:${clipboard_db}?mode=ro" \
                "SELECT 1 FROM selection_fts WHERE content = '${sql_path}' LIMIT 1;" | grep -q 1; then
                break
            fi
            sleep 0.02
        done
    else
        sleep 0.2
    fi
    tick=$(date +%s)
    while [ "$(date +%s)" = "$tick" ]; do
        sleep 0.05
    done
    wl-copy --type image/png < "$FILENAME"
    notify-send "Screenshot captured" "Saved to $(basename "$FILENAME")"
else
    rm -f "$TEMP_FILE"
    notify-send "Screenshot failed" "Error capturing screenshot"
fi 