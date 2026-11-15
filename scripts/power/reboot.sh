#!/usr/bin/env bash

hyprctl dispatch 'hl.dsp.exec_cmd("hyprshutdown -t \"Rebooting...\" --post-cmd \"systemctl reboot\"")'
