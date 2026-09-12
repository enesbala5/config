#!/usr/bin/env bash
# Restore the BYOK agent VM from its golden snapshot.
# 
# After first successful provision + harness smoke test:
#   incus snapshot create byok-agent golden
#
# Use this when the guest toolchain is trashed, disk is full of junk, or the
# agent left the VM in a bad state. Prefer restore over ad-hoc repair for v1.
#
# Secrets are not in the snapshot — re-push via agent-vm-manage.sh push-secrets
# before the next job (or just `agent-vm-manage.sh run`, which pushes them).
#
# Env overrides:
#   VM_NAME          default: byok-agent
#   SNAPSHOT_NAME    default: golden

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

echo "==> Restored. Re-push secrets on the next agent-vm-manage.sh run (or push-secrets)."
