#!/usr/bin/env bash

count=$(pactl list short sinks | grep -vic "easyeffects")
[ "$count" -gt 1 ] && echo "⇄"
