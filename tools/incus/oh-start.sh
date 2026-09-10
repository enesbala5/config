#!/usr/bin/env bash
# Single OpenHands Agent Server client. Not a daemon, not an event mapper.
#
# Usage:
#   oh-start.sh --prompt "..." [--repo URL] [--model ID] [--workdir PATH]
#
# Prints:
#   conversation_id=...
#   https://agent.enesbala.com/conversations/...
#
# Env:
#   OPENHANDS_AGENT_SERVER_URL  default: http://127.0.0.1:8000 if /etc/agent-env
#                               exists, else http://byok-agent.incus:8000
#   OPENHANDS_UI_URL            default: https://agent.enesbala.com
#   OH_SESSION_API_KEYS_0 or OH_SESSION_API_KEY  required
#   WORKSPACE_DIR               default: /var/lib/ai-agent/workspace
#   LLM_MODEL / DEFAULT_MODEL / LLM_API_KEY / DEEPSEEK_API_KEY / LLM_BASE_URL

set -euo pipefail

for envfile in /etc/agent-env /etc/hermes-env; do
  if [[ -f "$envfile" ]]; then
    set -o allexport
    # shellcheck disable=SC1090
    source "$envfile"
    set +o allexport
  fi
done

if [[ -f /etc/agent-env ]]; then
  AGENT_SERVER="${OPENHANDS_AGENT_SERVER_URL:-http://127.0.0.1:8000}"
else
  AGENT_SERVER="${OPENHANDS_AGENT_SERVER_URL:-http://byok-agent.incus:8000}"
fi

AGENT_SERVER="${AGENT_SERVER%/}"
UI_BASE="${OPENHANDS_UI_URL:-https://agent.enesbala.com}"
UI_BASE="${UI_BASE%/}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/var/lib/ai-agent/workspace}"
SESSION_KEY="${OH_SESSION_API_KEYS_0:-${OH_SESSION_API_KEY:-${OPENHANDS_SESSION_API_KEY:-${SESSION_API_KEY:-}}}}"
LLM_KEY="${LLM_API_KEY:-${DEEPSEEK_API_KEY:-}}"
MODEL="${LLM_MODEL:-${DEFAULT_MODEL:-deepseek/deepseek-chat}}"
BASE_URL="${LLM_BASE_URL:-https://api.deepseek.com}"
MAX_ITERATIONS="${OPENHANDS_MAX_ITERATIONS:-100}"

PROMPT=""
REPO=""
WORKDIR=""

usage() {
  cat >&2 <<'EOF'
Usage:
  oh-start.sh --prompt TEXT [--repo URL] [--model ID] [--workdir PATH]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      PROMPT="${2:?--prompt requires text}"
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
    --workdir)
      WORKDIR="${2:?--workdir requires a path}"
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

if [[ -z "$PROMPT" ]]; then
  echo "Error: --prompt is required" >&2
  usage
  exit 1
fi

if [[ -z "$SESSION_KEY" ]]; then
  echo "Error: OH_SESSION_API_KEYS_0 (or OH_SESSION_API_KEY) is required" >&2
  exit 1
fi

working_dir="${WORKDIR:-$WORKSPACE_DIR}"
local_agent=0
case "$AGENT_SERVER" in
  http://127.0.0.1:*|http://localhost:*|http://0.0.0.0:*) local_agent=1 ;;
esac

if [[ -n "$REPO" && "$local_agent" -eq 1 ]]; then
  mkdir -p "$WORKSPACE_DIR"
  name="$(basename "${REPO%.git}")"
  [[ -n "$name" ]] || name="repo"
  dest="${WORKSPACE_DIR}/${name}"
  clone_url="$REPO"
  if [[ -n "${GITHUB_TOKEN:-}" && "$REPO" == https://github.com/* ]]; then
    clone_url="${REPO/https:\/\/github.com\//https:\/\/x-access-token:${GITHUB_TOKEN}@github.com/}"
    git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/" || true
  fi
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" fetch --all || true
    git -C "$dest" pull --ff-only || true
  else
    git clone "$clone_url" "$dest"
  fi
  working_dir="$dest"
elif [[ -n "$REPO" ]]; then
  PROMPT="${PROMPT}

Repository: ${REPO}
Working directory on the agent host: ${working_dir}
Clone the repo there if it is not already present."
fi

notify() {
  if [[ -x /usr/local/bin/notify.sh ]]; then
    /usr/local/bin/notify.sh -m md "$1" || true
  fi
}

HOST_LABEL="$(hostname)"
REPO_LABEL="${REPO:-none}"
notify "OpenHands conversation started
Host: ${HOST_LABEL}
Repo: ${REPO_LABEL}
Model: ${MODEL}"

BODY="$(jq -n \
  --arg prompt "$PROMPT" \
  --arg model "$MODEL" \
  --arg api_key "$LLM_KEY" \
  --arg base_url "$BASE_URL" \
  --arg working_dir "$working_dir" \
  --argjson max_iterations "$MAX_ITERATIONS" \
  '{
    agent: {
      kind: "Agent",
      llm: (
        {model: $model, api_key: $api_key}
        + (if $base_url == "" then {} else {base_url: $base_url} end)
      ),
      tools: [
        {name: "TerminalTool"},
        {name: "FileEditorTool"},
        {name: "TaskTrackerTool"}
      ],
      system_prompt_kwargs: {cli_mode: true}
    },
    workspace: {working_dir: $working_dir},
    initial_message: {
      role: "user",
      content: [{type: "text", text: $prompt}]
    },
    max_iterations: $max_iterations,
    stuck_detection: true,
    confirmation_policy: {kind: "NeverConfirm"}
  }')"

auth_headers=(
  -H "Content-Type: application/json"
  -H "Accept: application/json"
  -H "X-Session-API-Key: ${SESSION_KEY}"
  -H "Authorization: Bearer ${SESSION_KEY}"
)

RESPONSE="$(curl -fsS "${auth_headers[@]}" -X POST "${AGENT_SERVER}/api/conversations" -d "$BODY")" || {
  notify "OpenHands conversation failed
Host: ${HOST_LABEL}
Repo: ${REPO_LABEL}
Create POST failed"
  echo "Error: POST ${AGENT_SERVER}/api/conversations failed" >&2
  exit 1
}

CONV_ID="$(printf '%s' "$RESPONSE" | jq -r '.id // .conversation_id // empty')"
if [[ -z "$CONV_ID" || "$CONV_ID" == "null" ]]; then
  echo "Error: Agent Server did not return a conversation id" >&2
  printf '%s\n' "$RESPONSE" >&2
  notify "OpenHands conversation failed
Host: ${HOST_LABEL}
Repo: ${REPO_LABEL}
Missing conversation id"
  exit 1
fi

curl -fsS "${auth_headers[@]}" -X POST "${AGENT_SERVER}/api/conversations/${CONV_ID}/run" >/dev/null || true

UI_URL="${UI_BASE}/conversations/${CONV_ID}"
echo "conversation_id=${CONV_ID}"
echo "$UI_URL"
