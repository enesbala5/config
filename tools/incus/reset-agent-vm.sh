#!/usr/bin/env bash
# Restore the BYOK agent VM from its golden snapshot via Incus REST.
#
# After first successful provision + harness smoke test:
#   POST /1.0/instances/byok-agent/snapshots  {"name":"golden"}
#
# Secrets are not in the snapshot — re-push via run-agent-task.sh before the
# next job (it pushes /etc/agent-env each run).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/incus-rest.sh"

VM_NAME="${VM_NAME:-byok-agent}"
SNAPSHOT_NAME="${SNAPSHOT_NAME:-golden}"

if ! incus_instance_exists "$VM_NAME"; then
  echo "Error: VM ${VM_NAME} does not exist" >&2
  exit 1
fi

echo "==> Stopping ${VM_NAME}..."
incus_instance_stop "$VM_NAME"

echo "==> Restoring snapshot ${SNAPSHOT_NAME}..."
incus_request PUT "/1.0/instances/${VM_NAME}" \
  "{\"restore\":\"${SNAPSHOT_NAME}\"}" >/dev/null

echo "==> Starting ${VM_NAME}..."
incus_instance_start "$VM_NAME"

echo "==> Restored. Re-push secrets on the next run-agent-task.sh invocation."
