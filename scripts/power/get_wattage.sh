#!/usr/bin/env bash

# Get charging status
status=$(cat /sys/class/power_supply/BAT1/status)

# Calculate power and format output
if [ "$status" = "Charging" ]; then
    awk "BEGIN {printf \"+%.1f W\n\", ($(cat /sys/class/power_supply/BAT1/current_now) * $(cat /sys/class/power_supply/BAT1/voltage_now)) / 1000000000000}"
else
    awk "BEGIN {printf \"%.1f W\n\", ($(cat /sys/class/power_supply/BAT1/current_now) * $(cat /sys/class/power_supply/BAT1/voltage_now)) / 1000000000000}"
fi