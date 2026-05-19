#!/usr/bin/env bash

hyprctl 'dispatch exec  hyprshutdown -t "Rebooting..." --post-cmd "systemctl reboot"'
