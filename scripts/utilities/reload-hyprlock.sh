#!/usr/bin/env bash

# Allow session lock restore
hyprctl --instance 0 eval 'hl.config({ misc = { allow_session_lock_restore = true } })'

pkill -SIGUSR1 hyprlock

sleep 1

hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'
