#!/usr/bin/env bash

# Pick a screen pixel with slurp/grim (same stack as screenshots).
# hyprpicker overlays a layer surface and can crash Hyprland
# ([ERR] renderSurface: PBUFFER null); bash cannot catch that.

SELECTION=$(slurp -p 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$SELECTION" ]; then
    notify-send "No color selected" || true
    exit 0
fi

# grim PPM is P6 with maxval 255; last 3 bytes are the pixel RGB.
RGB=$(grim -g "$SELECTION" -t ppm - 2>/dev/null | tail -c 3 | od -An -tx1 | tr -d ' \n')
if [ ${#RGB} -ne 6 ]; then
    notify-send "Color picker failed" || true
    exit 0
fi

COLOR="#${RGB^^}"
printf '%s' "$COLOR" | wl-copy 2>/dev/null || true
notify-send "Color has been copied: $COLOR" || true
