#!/usr/bin/env bash
# Desktop recording CLI. No arguments preserves the region-picker/stop toggle.
# See --help; session state is shared with Waybar and cancel.sh.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}/screen-record-$UID}"
mkdir -p "$RUNTIME"
# Workers must not inherit the command lock: stop/status need it while recording.
if [[ "${1:-}" == "_worker" ]]; then
	exec node "$SCRIPT_DIR/screen-record.mjs" "$@"
fi
exec flock --close -w 20 "$RUNTIME/screen-record.lock" node "$SCRIPT_DIR/screen-record.mjs" "$@"
