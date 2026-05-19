#!/usr/bin/env bash

# Get current profile
current_profile=$(powerprofilesctl get)

# Define the sequence of profiles
case "$current_profile" in
    "power-saver")
        powerprofilesctl set balanced
        ;;
    "balanced")
        powerprofilesctl set performance
        ;;
    "performance")
        powerprofilesctl set power-saver
        ;;
    *)
        # If current profile is unknown, default to balanced
        powerprofilesctl set balanced
        ;;
esac

# Show the new profile (monitor service will handle notifications)
MESSAGE="Switched to: $(powerprofilesctl get | sed 's/\b\(.\)/\u\1/g')"
echo "$MESSAGE"