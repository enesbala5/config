#!/usr/bin/env bash

# Get the power profile and convert to titlecase
powerprofilesctl get | sed 's/\b\(.\)/\u\1/g'