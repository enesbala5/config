#!/usr/bin/env bash
# Host entrypoint for the persistent BYOK Incus AI agent VM.
#
# Starts (or reuses) the VM, pushes secrets, then creates an OpenHands
# conversation through the guest orchestrator. OpenHands Agent Server is the
# runtime; this script does not exec the agent CLI inside the VM.
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
#   OPENHANDS_URL default: http://byok-agent.incus:8090
#   WAIT          default: 1 (poll until the conversation finishes)

set -euo pipefail

VM_NAME="${VM_NAME:-byok-agent}"
PROFILE="${PROFILE:-byok-agent}"
IMAGE="${IMAGE:-images:ubuntu/24.04/cloud}"
SECRETS_PATH="${SECRETS_PATH:-/run/agenix/incus-ai-agent-secrets}"
OPENHANDS_URL="${OPENHANDS_URL:-http://byok-agent.incus:8090}"
WAIT="${WAIT:-1}"

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

wait_for_orchestrator() {
  local i
  echo "==> Waiting for OpenHands orchestrator at ${OPENHANDS_URL}..."
  for i in $(seq 1 90); do
    if curl -fsS "${OPENHANDS_URL}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Error: timed out waiting for ${OPENHANDS_URL}/health" >&2
  incus exec "$VM_NAME" -- systemctl status openhands-agent-server --no-pager || true
  incus exec "$VM_NAME" -- systemctl status openhands-task-api --no-pager || true
  return 1
}

echo "==> Ensuring Incus VM ${VM_NAME} exists..."
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

incus exec "$VM_NAME" -- systemctl restart openhands-agent-server openhands-task-api || true
wait_for_orchestrator

BODY="$(jq -n --arg prompt "$PROMPT" --arg repo "$REPO" --arg model "$MODEL" '{
  prompt: $prompt,
  repo: $repo,
  model: (if $model == "" then null else $model end)
}')"

echo "==> Creating OpenHands conversation via ${OPENHANDS_URL}/tasks..."
RESPONSE="$(curl -fsS -X POST "${OPENHANDS_URL}/tasks" \
  -H "Content-Type: application/json" \
  -d "$BODY")"
echo "$RESPONSE"

JOB_ID="$(printf '%s' "$RESPONSE" | jq -r '.conversation_id // .job_id')"
if [[ -z "$JOB_ID" || "$JOB_ID" == "null" ]]; then
  echo "Error: orchestrator did not return a conversation id" >&2
  exit 1
fi

if [[ "$WAIT" != "1" ]]; then
  echo "==> conversation_id=${JOB_ID} (not waiting)"
  exit 0
fi

echo "==> Streaming status for ${JOB_ID}..."
for _ in $(seq 1 360); do
  STATUS_JSON="$(curl -fsS "${OPENHANDS_URL}/tasks/${JOB_ID}" || true)"
  STATUS="$(printf '%s' "$STATUS_JSON" | jq -r '.status // empty')"
  OH_STATUS="$(printf '%s' "$STATUS_JSON" | jq -r '.oh_status // empty')"
  echo "    status=${STATUS} oh_status=${OH_STATUS}"
  case "$STATUS" in
    ok|finished)
      echo "==> Conversation finished"
      printf '%s\n' "$STATUS_JSON" | jq '.events[-8:]'
      exit 0
      ;;
    failed|error)
      echo "==> Conversation failed" >&2
      printf '%s\n' "$STATUS_JSON" | jq .
      exit 1
      ;;
    cancelled|paused)
      echo "==> Conversation ${STATUS}"
      printf '%s\n' "$STATUS_JSON" | jq '.events[-8:]'
      exit 0
      ;;
  esac
  sleep 5
done

echo "Error: timed out waiting for conversation ${JOB_ID}" >&2
exit 1
