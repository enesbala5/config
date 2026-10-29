#!/bin/sh
# After a long s2idle, Hyprland still marks the panel DPMS-on, so a plain
# "dpms on" does not modeset and the screen stays black until the next key.
# Toggle DPMS and write the backlight again so the panel actually lights.

export PATH="/run/current-system/sw/bin:/run/wrappers/bin:$PATH"

hyprctl dispatch 'hl.dsp.dpms("off")'
hyprctl dispatch 'hl.dsp.dpms("on")'

brillo -u 1 -S "$(brillo -G)"
