#!/usr/bin/env bash

hyprctl dispatch 'hl.dsp.exec_cmd("hyprshutdown -t \"Shutting down...\" --post-cmd \"systemctl poweroff\"")'