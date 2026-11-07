#!/bin/sh
# Turn the panel back on after lid open / resume.
# A plain "dpms on" is a no-op when Hyprland already thinks the panel is on.
# Only force an off/on modeset when DRM is still Off after "dpms on".
# Doing that off/on while the panel is already lit drops hyprlock's surface.

export PATH="/run/current-system/sw/bin:/run/wrappers/bin:$PATH"

lockdir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$lockdir"
exec 9>"$lockdir/wake-panel.lock"
flock -w 2 9 || exit 0

dpms_off() {
	for dpms in /sys/class/drm/card*-eDP-*/dpms; do
		[ -e "$dpms" ] || continue
		[ "$(cat "$dpms")" = "Off" ] && return 0
	done
	return 1
}

dpms_off || exit 0

hyprctl dispatch 'hl.dsp.dpms("on")'
dpms_off || exit 0

hyprctl dispatch 'hl.dsp.dpms("off")'
hyprctl dispatch 'hl.dsp.dpms("on")'

level=$(brillo -G 2>/dev/null | cut -d. -f1)
if [ -z "$level" ] || [ "$level" -eq 0 ]; then
	level=40
fi
brillo -u 1 -S "$level"
