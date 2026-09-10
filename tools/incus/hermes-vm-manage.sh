#!/usr/bin/env bash
# Host lifecycle for the persistent Hermes Agent Incus VM (incus CLI).
set -euo pipefail

VM_NAME="${VM_NAME:-hermes-agent}"
PROFILE="${PROFILE:-hermes-agent}"
IMAGE="${IMAGE:-images:ubuntu/24.04/cloud}"
SECRETS_PATH="${SECRETS_PATH:-/run/agenix/hermes-agent-secrets}"
USER_DATA_FILE="${USER_DATA_FILE:-/etc/incus-profiles/${PROFILE}/user-data}"
PROFILE_CPU="${PROFILE_CPU:-2}"
PROFILE_MEMORY="${PROFILE_MEMORY:-4GiB}"

usage() {
  cat >&2 <<'EOF'
Usage:
  hermes-vm-manage.sh start|stop|status|logs|push-secrets|launch
EOF
}

ensure_profile() {
  if incus profile show "$PROFILE" >/dev/null 2>&1; then
    return 0
  fi

  echo "==> Incus profile ${PROFILE} missing; creating it..."
  incus profile create "$PROFILE"
  incus profile set "$PROFILE" limits.cpu "$PROFILE_CPU"
  incus profile set "$PROFILE" limits.memory "$PROFILE_MEMORY"
  if [[ -f "$USER_DATA_FILE" ]]; then
    incus profile set "$PROFILE" cloud-init.user-data - < "$USER_DATA_FILE"
    incus profile set "$PROFILE" user.user-data - < "$USER_DATA_FILE"
  else
    echo "Warning: ${USER_DATA_FILE} not found; launched VM will not get cloud-init seeding until the host oneshot runs." >&2
  fi
}

wait_for_agent() {
  local i
  echo "==> Waiting for Incus agent on ${VM_NAME}..."
  for i in $(seq 1 90); do
    if incus exec "$VM_NAME" -- true >/dev/null 2>&1; then
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
  incus file push "$SECRETS_PATH" "${VM_NAME}/etc/hermes-env" \
    -p --mode 0600 --uid 0 --gid 0
}

cmd_launch() {
  ensure_profile
  if incus info "$VM_NAME" >/dev/null 2>&1; then
    echo "==> ${VM_NAME} already exists"
    return 0
  fi
  incus launch "$IMAGE" "$VM_NAME" --profile default --profile "$PROFILE" --vm
}

cmd_start() {
  if ! incus info "$VM_NAME" >/dev/null 2>&1; then
    cmd_launch
  else
    status="$(incus list "$VM_NAME" --format csv -c s 2>/dev/null || true)"
    if [[ "$status" != "RUNNING" ]]; then
      incus start "$VM_NAME" || true
    fi
  fi
  wait_for_agent
  if ! incus exec "$VM_NAME" -- /usr/bin/cloud-init status --wait; then
    incus exec "$VM_NAME" -- /usr/bin/cloud-init status --long || true
    incus exec "$VM_NAME" -- tail -n 120 /var/log/cloud-init-output.log || true
    exit 1
  fi
  push_secrets
  incus exec "$VM_NAME" -- systemctl start hermes-agent || true
}

cmd_stop() {
  incus exec "$VM_NAME" -- systemctl stop hermes-agent || true
  incus stop "$VM_NAME" || true
}

ACTION="${1:-}"
case "$ACTION" in
  launch) cmd_launch ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) incus list "$VM_NAME"; incus exec "$VM_NAME" -- systemctl status hermes-agent --no-pager || true ;;
  logs) incus exec "$VM_NAME" -- journalctl -u hermes-agent -n 80 --no-pager ;;
  push-secrets) push_secrets ;;
  -h|--help|"") usage; exit 0 ;;
  *) echo "Unknown argument: $ACTION" >&2; usage; exit 1 ;;
esac
