#!/usr/bin/env bash
# Restore the BYOK agent VM from its golden snapshot.
set -euo pipefail

VM_NAME="${VM_NAME:-byok-agent}"
SNAPSHOT_NAME="${SNAPSHOT_NAME:-golden}"

if ! incus info "$VM_NAME" >/dev/null 2>&1; then
  echo "Error: VM ${VM_NAME} does not exist" >&2
  exit 1
fi

echo "==> Stopping ${VM_NAME}..."
incus stop "$VM_NAME" || true

echo "==> Restoring snapshot ${SNAPSHOT_NAME}..."
incus snapshot restore "$VM_NAME" "$SNAPSHOT_NAME"

echo "==> Starting ${VM_NAME}..."
incus start "$VM_NAME"

echo "==> Restored. Re-push secrets on the next run-agent-task.sh invocation."
