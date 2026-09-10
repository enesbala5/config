#!/usr/bin/env bash
# Host entrypoint for the persistent BYOK Incus AI agent VM.
#
# Usage:
#   run-agent-task.sh --prompt "Fix flaky test in auth" [--repo https://github.com/org/repo.git] [--model ...]
#   run-agent-task.sh --prompt-file ./task.md [--repo ...] [--model ...]
#
# Env overrides:
#   VM_NAME       default: byok-agent
#   PROFILE       default: byok-agent
#   SECRETS_PATH  default: /run/agenix/incus-ai-agent-secrets
#
# Chat coordinators should call this script; do not bake secrets into prompts.
set -euo pipefail

VM_NAME="${VM_NAME:-byok-agent}"
PROFILE="${PROFILE:-byok-agent}"
SECRETS_PATH="${SECRETS_PATH:-/run/agenix/incus-ai-agent-secrets}"

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

echo "==> Ensuring Incus VM ${VM_NAME} exists..."
if ! incus info "$VM_NAME" >/dev/null 2>&1; then
  incus launch images:ubuntu/24.04 "$VM_NAME" \
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

# First boot blocks until cloud-init finishes; later boots return quickly.
echo "==> Waiting for cloud-init..."
incus exec "$VM_NAME" -- cloud-init status --wait

echo "==> Pushing secrets to guest /etc/agent-env (mode 0600)..."
incus file push "$SECRETS_PATH" "${VM_NAME}/etc/agent-env" \
  -p 0600 --uid 0 --gid 0

GUEST_ARGS=(--prompt "$PROMPT")
if [[ -n "$REPO" ]]; then
  GUEST_ARGS+=(--repo "$REPO")
fi
if [[ -n "$MODEL" ]]; then
  GUEST_ARGS+=(--model "$MODEL")
fi

echo "==> Running guest-run-agent-task.sh..."
incus exec "$VM_NAME" -- /usr/local/bin/guest-run-agent-task.sh "${GUEST_ARGS[@]}"
