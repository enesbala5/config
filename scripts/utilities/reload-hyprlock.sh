#!/usr/bin/env bash

# Allow session lock restore
hyprctl --instance 0 'keyword misc:allow_session_lock_restore 1'

pkill -SIGUSR1 hyprlock

sleep 1

hyprctl --instance 0 'dispatch exec hyprlock'
