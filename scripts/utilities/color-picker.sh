#!/usr/bin/env bash

# Run hyprpicker 
# hyprpicker handles copying to clipboard automatically

# If the color has been set, do the following:
# -> Notify the user that the color has been copied to the clipboard
# -> Display the color in the notification as well

# If the color has not been set, do the following:
# -> Notify the user that no color has been set

COLOR=$(timeout 30 hyprpicker -a 2>/dev/null | grep -oE '#[0-9a-fA-F]{6}')
EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
    notify-send "Color picker timed out"
elif [ $EXIT_CODE -ne 0 ] || [ -z "$COLOR" ]; then
    notify-send "No color selected"
else
    notify-send "Color has been copied: $COLOR"
fi
