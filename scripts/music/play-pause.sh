#!/usr/bin/env bash
# Toggle play/pause on the current media player (playerctl).
#
# Wired to $mainMod + P.

playerctl --ignore-player=kdeconnect play-pause
