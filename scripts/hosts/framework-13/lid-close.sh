#!/bin/sh
# s2idle does not cut the panel backlight. logind also ignores lid events
# for 30s after resume, so the screen stays on unless we turn it off here.

export PATH="/run/current-system/sw/bin:/run/wrappers/bin:$PATH"

lockdir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mkdir -p "$lockdir"
exec 9>"$lockdir/wake-panel.lock"
flock -n 9 || exit 0

hyprctl dispatch 'hl.dsp.dpms("off")'

# A resume replays lid-close and lid-open back to back. If the lid is
# open again, put the panel back and do not lock or suspend.
sleep 0.4
state=$(awk '{print $2}' /proc/acpi/button/lid/LID0/state)
if [ "$state" != "closed" ]; then
	hyprctl dispatch 'hl.dsp.dpms("on")'
	exit 0
fi

pidof hyprlock >/dev/null || hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")'

# logind suspends on its own outside the post-resume holdoff.
exec 9>&-
if systemctl is-active --quiet systemd-suspend.service; then
	exit 0
fi
if systemctl list-jobs --no-legend 2>/dev/null | grep -q suspend; then
	exit 0
fi
systemctl suspend
