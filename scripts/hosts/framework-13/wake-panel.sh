#!/bin/sh
# Turn the panel back on after idle activity, lid open, or resume.
# Always tell Hyprland to wake: its DPMS state can disagree with DRM.
# Only force an off/on modeset if DRM stays Off after a short settling period.
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

hyprctl dispatch 'hl.dsp.dpms("on")' || exit 1

# The GPU may still be resuming. Give the wake command time to take effect
# before deciding a modeset is needed.
attempt=0
while dpms_off && [ "$attempt" -lt 5 ]; do
	sleep 0.2
	attempt=$((attempt + 1))
done
if dpms_off; then
	hyprctl dispatch 'hl.dsp.dpms("off")'
	hyprctl dispatch 'hl.dsp.dpms("on")'
fi

# Reapply the backlight even when DPMS was already On. Resume can leave
# the hardware dark despite both Hyprland and DRM reporting an awake panel.

level=$(brillo -G 2>/dev/null | cut -d. -f1)
if [ -z "$level" ] || [ "$level" -eq 0 ]; then
	level=40
fi
brillo -u 1 -S "$level"
