#!/usr/bin/env bash

# RClone Bisync Script
# This script runs rclone bisync with standard parameters and accepts additional flags

set -uo pipefail

# Configuration - use environment variables if set, otherwise defaults
REMOTE_NAME="${RCLONE_REMOTE_NAME:-gdrive}"
LOCAL_DIR="${RCLONE_LOCAL_DIR:-/home/${USER}/gdrive}"

# Ensure local directory exists
mkdir -p "${LOCAL_DIR}"

# Collect any additional flags passed as arguments
EXTRA_FLAGS="$*"

# If --resync is explicitly passed in arguments, don't add it again
# Otherwise, auto-detect if resync is needed (empty directory)
RESYNC_FLAG=""

if [[ "$EXTRA_FLAGS" == *"--resync"* ]]; then
  RESYNC_FLAG=""
elif [ -z "$(ls -A "${LOCAL_DIR}" 2>/dev/null)" ]; then
  RESYNC_FLAG="--resync"
fi

# Run rclone bisync with all parameters
# Note: rclone should be in PATH (set by systemd service or system)

echo "Running rclone bisync with the following flags: ${RESYNC_FLAG} ${EXTRA_FLAGS}"

rclone bisync \
  "${REMOTE_NAME}:" \
  "${LOCAL_DIR}" \
  -MvP \
  --create-empty-src-dirs \
  --compare size,modtime,checksum \
  --conflict-resolve newer \
  --conflict-loser delete \
  --conflict-suffix sync-conflict-{DateOnly}- \
  --suffix-keep-extension \
  --resilient \
  --max-lock 2m \
  --recover \
  --no-slow-hash \
  --drive-skip-gdocs \
  --fix-case \
  --metadata-exclude owner \
  --metadata-exclude uid \
  --metadata-exclude gid \
  --metadata-exclude user \
  --metadata-exclude group \
  ${RESYNC_FLAG} \
  ${EXTRA_FLAGS}

EXIT_CODE=$?

# rclone bisync exits with code 2 when a critical error requires a full resync.
# Notify the user but always exit 0 so the systemd service doesn't crash.
if [ "${EXIT_CODE}" -eq 2 ]; then
  MSG="RClone bisync aborted — a full resync is required. Run 'rclone-resync' to fix."
  notify-send --urgency=critical "🚨 RClone Sync Error" "${MSG}" || true
  echo "ERROR: ${MSG}" >&2
elif [ "${EXIT_CODE}" -ne 0 ]; then
  MSG="RClone bisync finished with errors (exit code ${EXIT_CODE}). Check logs with 'rclone-logs'."
  notify-send --urgency=critical "🚨 RClone Sync Warning" "${MSG}" || true
  echo "WARNING: ${MSG}" >&2
fi

exit 0
