#!/usr/bin/env bash
# Host lifecycle for the persistent BYOK OpenHands Incus agent VM (incus CLI).
#
# Counterpart to hermes-vm-manage.sh. `run` is the BYOK-specific addition: it
# brings the VM up, then dispatches a headless OpenHands conversation through
# the guest oh-start.sh client against Agent Server :8000.
set -euo pipefail

VM_NAME="${VM_NAME:-byok-agent}"
PROFILE="${PROFILE:-byok-agent}"
IMAGE="${IMAGE:-images:ubuntu/24.04/cloud}"
SECRETS_PATH="${SECRETS_PATH:-/run/agenix/incus-ai-agent-secrets}"
USER_DATA_FILE="${USER_DATA_FILE:-/etc/incus-profiles/${PROFILE}/user-data}"
PROFILE_CPU="${PROFILE_CPU:-4}"
PROFILE_MEMORY="${PROFILE_MEMORY:-8GiB}"
# Keep in sync with hosts/home-server/default.nix (guestIps) and the
# incus-ai-agent module's network.nic.
NIC="${NIC:-eth0}"
STATIC_IP="${STATIC_IP:-10.0.100.173}"

usage() {
  cat >&2 <<'EOF'
Usage:
  agent-vm-manage.sh start|stop|status|logs|push-secrets|launch
  agent-vm-manage.sh run --prompt TEXT [--repo URL] [--model ID]
  agent-vm-manage.sh run --prompt-file PATH [--repo URL] [--model ID]
EOF
}

STATIC_IP_CHANGED=0

# Pin the guest IP. Sets STATIC_IP_CHANGED=1 when the address changed, so a
# running guest can be rebooted to pick up its new DHCP reservation.
ensure_static_ip() {
  STATIC_IP_CHANGED=0
  [[ -n "$STATIC_IP" ]] || return 0
  local current
  current="$(incus config device get "$VM_NAME" "$NIC" ipv4.address 2>/dev/null || true)"
  if [[ "$current" != "$STATIC_IP" ]]; then
    echo "==> Pinning ${VM_NAME} ${NIC} ipv4.address=${STATIC_IP}"
    incus config device set "$VM_NAME" "$NIC" ipv4.address "$STATIC_IP"
    STATIC_IP_CHANGED=1
  fi
  # An already-running guest can keep its old dynamic lease until it reboots.
  if [[ "$(incus list "$VM_NAME" --format csv -c s 2>/dev/null || true)" == "RUNNING" ]]; then
    local runtime_ip
    runtime_ip="$(incus list "$VM_NAME" --format csv -c 4 2>/dev/null | cut -d' ' -f1 || true)"
    if [[ -n "$runtime_ip" && "$runtime_ip" != "$STATIC_IP" ]]; then
      STATIC_IP_CHANGED=1
    fi
  fi
}

ensure_profile() {
  if ! incus profile show "$PROFILE" >/dev/null 2>&1; then
    echo "==> Incus profile ${PROFILE} missing; creating it..."
    incus profile create "$PROFILE"
  fi

  incus profile set "$PROFILE" limits.cpu "$PROFILE_CPU"
  incus profile set "$PROFILE" limits.memory "$PROFILE_MEMORY"
  incus profile set "$PROFILE" security.nesting true
  if [[ -f "$USER_DATA_FILE" ]]; then
    # Always refresh: an empty profile from an earlier partial setup would
    # otherwise leave new VMs with cloud-init user-data: {}.
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

wait_for_agent_server() {
  local i
  echo "==> Waiting for OpenHands Agent Server on ${VM_NAME}:8000..."
  for i in $(seq 1 90); do
    if incus exec "$VM_NAME" -- curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Error: timed out waiting for Agent Server :8000" >&2
  incus exec "$VM_NAME" -- systemctl status openhands-agent-server --no-pager || true
  return 1
}

# Keep in sync with nix/nixos/hosts/home-server/modules/incus-ai-agent/default.nix
ensure_agent_env() {
  echo "==> Installing guest env loader (source /etc/agent-env)..."
  incus exec "$VM_NAME" -- tee /etc/profile.d/agent-env.sh >/dev/null <<'EOF'
# Export /etc/agent-env for OpenHands CLI and login shells (incus exec bash -l).
if [ -f /etc/agent-env ]; then
  set -a
  . /etc/agent-env
  set +a
fi
EOF
  incus exec "$VM_NAME" -- chmod 0644 /etc/profile.d/agent-env.sh
}

push_secrets() {
  if [[ ! -e "$SECRETS_PATH" ]]; then
    echo "Error: secret file $SECRETS_PATH not found. Encrypt with manage-secret and apply agenix first." >&2
    exit 1
  fi
  echo "==> Pushing secrets to guest /etc/agent-env (mode 0600)..."
  # agenix decrypts as root:0400; incus file push must not open the path as the caller.
  if [[ -r "$SECRETS_PATH" ]]; then
    incus file push "$SECRETS_PATH" "${VM_NAME}/etc/agent-env" \
      -p --mode 0600 --uid 0 --gid 0
  else
    sudo cat "$SECRETS_PATH" | incus file push - "${VM_NAME}/etc/agent-env" \
      -p --mode 0600 --uid 0 --gid 0
  fi
}

cmd_launch() {
  ensure_profile
  if incus info "$VM_NAME" >/dev/null 2>&1; then
    echo "==> ${VM_NAME} already exists"
    return 0
  fi
  # Create without starting so the pinned IP is reserved before the guest's
  # first DHCP request. `incus launch` would boot it with a dynamic lease.
  incus init "$IMAGE" "$VM_NAME" --profile default --profile "$PROFILE" --vm
  ensure_static_ip
  incus start "$VM_NAME"
}

cmd_start() {
  if ! incus info "$VM_NAME" >/dev/null 2>&1; then
    cmd_launch
  else
    ensure_static_ip
    status="$(incus list "$VM_NAME" --format csv -c s 2>/dev/null || true)"
    if [[ "$status" != "RUNNING" ]]; then
      incus start "$VM_NAME" || true
    elif [[ "$STATIC_IP_CHANGED" == "1" ]]; then
      # A running guest keeps its old lease until it reboots/renews.
      incus restart "$VM_NAME" || true
    fi
  fi
  wait_for_agent
  if ! incus exec "$VM_NAME" -- /usr/bin/cloud-init status --wait; then
    echo "Error: cloud-init failed on ${VM_NAME}" >&2
    incus exec "$VM_NAME" -- /usr/bin/cloud-init status --long || true
    incus exec "$VM_NAME" -- tail -n 120 /var/log/cloud-init-output.log || true
    exit 1
  fi
  push_secrets
  if ! incus exec "$VM_NAME" -- test -f /etc/systemd/system/openhands-agent-server.service; then
    echo "Error: openhands-agent-server.service missing in guest. VM likely first-booted without profile user-data." >&2
    echo "Recreate: incus stop ${VM_NAME} && incus delete ${VM_NAME} && $0 start" >&2
    exit 1
  fi
  ensure_agent_env
  incus exec "$VM_NAME" -- systemctl restart openhands-agent-server || true
  wait_for_agent_server
}

cmd_stop() {
  incus exec "$VM_NAME" -- systemctl stop openhands-agent-server || true
  incus stop "$VM_NAME" || true
}

cmd_run() {
  local prompt="" prompt_file="" repo="" model=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prompt)
        prompt="${2:?--prompt requires text}"
        shift 2
        ;;
      --prompt-file)
        prompt_file="${2:?--prompt-file requires a path}"
        shift 2
        ;;
      --repo)
        repo="${2:?--repo requires a URL}"
        shift 2
        ;;
      --model)
        model="${2:?--model requires an id}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ -n "$prompt_file" ]]; then
    if [[ ! -f "$prompt_file" ]]; then
      echo "Error: prompt file not found: $prompt_file" >&2
      exit 1
    fi
    prompt="$(cat "$prompt_file")"
  fi

  if [[ -z "$prompt" ]]; then
    echo "Error: --prompt or --prompt-file is required" >&2
    usage
    exit 1
  fi

  cmd_start

  local args=(--prompt "$prompt")
  if [[ -n "$repo" ]]; then
    args+=(--repo "$repo")
  fi
  if [[ -n "$model" ]]; then
    args+=(--model "$model")
  fi

  echo "==> Creating OpenHands conversation via guest oh-start.sh..."
  incus exec "$VM_NAME" -- /usr/local/bin/oh-start.sh "${args[@]}"
}

ACTION="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi
case "$ACTION" in
  launch) cmd_launch ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  run) cmd_run "$@" ;;
  status) incus list "$VM_NAME"; incus exec "$VM_NAME" -- systemctl status openhands-agent-server --no-pager || true ;;
  logs) incus exec "$VM_NAME" -- journalctl -u openhands-agent-server -n 80 --no-pager ;;
  push-secrets) push_secrets ;;
  -h|--help|"") usage; exit 0 ;;
  *) echo "Unknown argument: $ACTION" >&2; usage; exit 1 ;;
esac
