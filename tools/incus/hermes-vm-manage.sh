#!/usr/bin/env bash
# Host lifecycle for the persistent Hermes Agent Incus VM.
# Talks to Incus over the local REST unix socket (no `incus` CLI).
#
# Usage:
#   hermes-vm-manage.sh start|stop|status|logs|push-secrets|launch
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/incus-rest.sh"

VM_NAME="${VM_NAME:-hermes-agent}"
PROFILE="${PROFILE:-hermes-agent}"
IMAGE="${IMAGE:-ubuntu/24.04/cloud}"
SECRETS_PATH="${SECRETS_PATH:-/run/agenix/hermes-agent-secrets}"

usage() {
  cat >&2 <<'EOF'
Usage:
  hermes-vm-manage.sh start|stop|status|logs|push-secrets|launch
EOF
}

wait_for_agent() {
  local i
  echo "==> Waiting for Incus agent on ${VM_NAME}..."
  for i in $(seq 1 90); do
    if incus_instance_exec "$VM_NAME" true >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Error: timed out waiting for Incus agent on ${VM_NAME}" >&2
  return 1
}

push_secrets() {
  if [[ ! -f "$SECRETS_PATH" ]]; then
    echo "Error: secret file $SECRETS_PATH not found. Encrypt with manage-secret and apply agenix first." >&2
    exit 1
  fi
  echo "==> Pushing secrets to guest /etc/hermes-env (mode 0600)..."
  incus_file_push "$VM_NAME" "$SECRETS_PATH" "/etc/hermes-env" "0600" 0 0
}

cmd_launch() {
  if incus_instance_exists "$VM_NAME"; then
    echo "==> ${VM_NAME} already exists"
    return 0
  fi
  echo "==> Creating Incus VM ${VM_NAME} via REST..."
  incus_instance_create "$VM_NAME" "$IMAGE" "$PROFILE"
}

cmd_start() {
  if ! incus_instance_exists "$VM_NAME"; then
    cmd_launch
  fi
  local status
  status="$(incus_instance_status "$VM_NAME" 2>/dev/null || echo Stopped)"
  if [[ "$status" != "Running" ]]; then
    echo "==> Starting ${VM_NAME}..."
    incus_instance_start "$VM_NAME"
  fi
  wait_for_agent
  echo "==> Waiting for cloud-init..."
  if ! incus_instance_exec "$VM_NAME" /usr/bin/cloud-init status --wait; then
    echo "Error: cloud-init failed on ${VM_NAME}" >&2
    incus_instance_exec "$VM_NAME" /usr/bin/cloud-init status --long || true
    incus_instance_exec "$VM_NAME" tail -n 120 /var/log/cloud-init-output.log || true
    exit 1
  fi
  push_secrets
  echo "==> Starting hermes-agent.service..."
  incus_instance_exec "$VM_NAME" systemctl start hermes-agent || true
}

cmd_stop() {
  if ! incus_instance_exists "$VM_NAME"; then
    echo "Error: VM ${VM_NAME} does not exist" >&2
    exit 1
  fi
  incus_instance_exec "$VM_NAME" systemctl stop hermes-agent || true
  echo "==> Stopping ${VM_NAME}..."
  incus_instance_stop "$VM_NAME"
}

cmd_status() {
  if ! incus_instance_exists "$VM_NAME"; then
    echo "missing"
    exit 1
  fi
  echo "instance: $(incus_instance_status "$VM_NAME")"
  incus_instance_exec "$VM_NAME" systemctl status hermes-agent --no-pager || true
}

cmd_logs() {
  incus_instance_exec "$VM_NAME" journalctl -u hermes-agent -n 80 --no-pager
}

ACTION="${1:-}"
case "$ACTION" in
  launch) cmd_launch ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  logs) cmd_logs ;;
  push-secrets)
    if ! incus_instance_exists "$VM_NAME"; then
      echo "Error: VM ${VM_NAME} does not exist" >&2
      exit 1
    fi
    push_secrets
    ;;
  -h|--help|"")
    usage
    exit 0
    ;;
  *)
    echo "Unknown argument: $ACTION" >&2
    usage
    exit 1
    ;;
esac
