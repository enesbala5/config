#!/usr/bin/env bash
# Cancel in-progress capture actions (does not save / finalize).
#
# Wired to $mainMod + C. Add new --cancel handlers here rather than
# stuffing them into a feature-specific toggle script.

SCRIPTS="$(cd "$(dirname "$0")/.." && pwd)"

"$SCRIPTS/utilities/screen-record.sh" --cancel
"$SCRIPTS/audio/handy-bt-toggle.sh" --cancel
