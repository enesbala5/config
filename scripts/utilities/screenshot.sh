#!/usr/bin/env bash

# Take a screenshot using grim and slurp
# Save it to the user's pictures directory only if valid
# Copy it to clipboard
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
    # Copy to clipboard
    cat "$TEMP_FILE" | wl-copy
    # Save the file
    mv "$TEMP_FILE" "$FILENAME"
    notify-send "Screenshot captured" "Saved to $FILENAME and copied to clipboard"
else
    rm -f "$TEMP_FILE"
    notify-send "Screenshot failed" "Error capturing screenshot"
fi 