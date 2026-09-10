#!/usr/bin/env bash
# Host entrypoint for the persistent BYOK Incus AI agent VM.
#
# Starts (or reuses) the VM, pushes secrets, then runs the guest start
# client against OpenHands Agent Server :8000. Not an orchestrator.
#
# Usage:
#   run-agent-task.sh --prompt "Fix flaky test in auth" [--repo URL] [--model ID]
#   run-agent-task.sh --prompt-file ./task.md [--repo ...] [--model ...]
#
# Env overrides:
#   VM_NAME       default: byok-agent
#   PROFILE       default: byok-agent
#   IMAGE         default: images:ubuntu/24.04/cloud
#   SECRETS_PATH  default: /run/agenix/incus-ai-agent-secrets

set -euo pipefail

VM_NAME="${VM_NAME:-byok-agent}"
PROFILE="${PROFILE:-byok-agent}"
IMAGE="${IMAGE:-images:ubuntu/24.04/cloud}"
SECRETS_PATH="${SECRETS_PATH:-/run/agenix/incus-ai-agent-secrets}"
USER_DATA_FILE="${USER_DATA_FILE:-/etc/incus-profiles/${PROFILE}/user-data}"
PROFILE_CPU="${PROFILE_CPU:-4}"
PROFILE_MEMORY="${PROFILE_MEMORY:-8GiB}"

PROMPT=""
PROMPT_FILE=""
REPO=""
MODEL=""

usage() {
  cat >&2 <<'EOF'
Usage:
  run-agent-task.sh --prompt TEXT [--repo URL] [--model ID]
  run-agent-task.sh --prompt-file PATH [--repo URL] [--model ID]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      PROMPT="${2:?--prompt requires text}"
      shift 2
      ;;
    --prompt-file)
      PROMPT_FILE="${2:?--prompt-file requires a path}"
      shift 2
      ;;
    --repo)
      REPO="${2:?--repo requires a URL}"
      shift 2
      ;;
    --model)
      MODEL="${2:?--model requires an id}"
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

if [[ -n "$PROMPT_FILE" ]]; then
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "Error: prompt file not found: $PROMPT_FILE" >&2
    exit 1
  fi
  PROMPT="$(cat "$PROMPT_FILE")"
fi

if [[ -z "$PROMPT" ]]; then
  echo "Error: --prompt or --prompt-file is required" >&2
  usage
  exit 1
fi

if [[ ! -f "$SECRETS_PATH" ]]; then
  echo "Error: secret file $SECRETS_PATH not found. Encrypt with manage-secret and apply agenix first." >&2
  exit 1
fi

ensure_profile() {
  if incus profile show "$PROFILE" >/dev/null 2>&1; then
    return 0
  fi

  echo "==> Incus profile ${PROFILE} missing; creating it..."
  incus profile create "$PROFILE"
  incus profile set "$PROFILE" limits.cpu "$PROFILE_CPU"
  incus profile set "$PROFILE" limits.memory "$PROFILE_MEMORY"
  incus profile set "$PROFILE" security.nesting true
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

echo "==> Ensuring Incus VM ${VM_NAME} exists..."
ensure_profile
if ! incus info "$VM_NAME" >/dev/null 2>&1; then
  incus launch "$IMAGE" "$VM_NAME" \
    --profile default \
    --profile "$PROFILE" \
    --vm
else
  status="$(incus list "$VM_NAME" --format csv -c s 2>/dev/null || true)"
  if [[ "$status" != "RUNNING" ]]; then
    echo "==> Starting ${VM_NAME}..."
    incus start "$VM_NAME" || true
  fi
fi

wait_for_agent

echo "==> Waiting for cloud-init..."
if ! incus exec "$VM_NAME" -- /usr/bin/cloud-init status --wait; then
  echo "Error: cloud-init failed on ${VM_NAME}" >&2
  incus exec "$VM_NAME" -- /usr/bin/cloud-init status --long || true
  incus exec "$VM_NAME" -- tail -n 120 /var/log/cloud-init-output.log || true
  exit 1
fi

echo "==> Pushing secrets to guest /etc/agent-env (mode 0600)..."
incus file push "$SECRETS_PATH" "${VM_NAME}/etc/agent-env" \
  -p --mode 0600 --uid 0 --gid 0

incus exec "$VM_NAME" -- systemctl restart openhands-agent-server || true
wait_for_agent_server

args=(--prompt "$PROMPT")
if [[ -n "$REPO" ]]; then
  args+=(--repo "$REPO")
fi
if [[ -n "$MODEL" ]]; then
  args+=(--model "$MODEL")
fi

echo "==> Creating OpenHands conversation via guest oh-start.sh..."
incus exec "$VM_NAME" -- /usr/local/bin/oh-start.sh "${args[@]}"
