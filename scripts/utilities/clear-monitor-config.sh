#!/usr/bin/env bash

sh -c ''> ~/.config/hypr/monitors.conf
pkill -9 -f hyprdynamicmonitors

notify-send "Monitor config cleared"
