#!/usr/bin/env bash

hyprctl 'dispatch exec  hyprshutdown -t "Shutting down..." --post-cmd "systemctl poweroff"'