#!/usr/bin/env bash
# Single OpenHands Agent Server client. Not a daemon, not an event mapper.
#
# Usage:
#   oh-start.sh --prompt "..." [--file FILE]... [--file-upload] [--repo URL] [--model ID] [--workdir PATH]
#
# --file FILE is repeatable and accepts any file:
#   * Images (png/jpg/jpeg/gif/webp/bmp/tif/tiff) are embedded in the initial
#     message as image content (base64 data URL) so a vision-capable model can
#     see them. Text-only models silently ignore them (see OH note below).
#   * Any other file is treated as text: by default its contents are inlined
#     into the prompt; with --file-upload it is uploaded into the agent
#     workspace via the Agent Server file API (POST /api/file/upload) and
#     referenced by path. A failed upload falls back to inlining.
#
# --md is kept as an alias for --file (it used to accept only Markdown).
#
# NOTE: embedded images reach the model only when the selected LLM supports
# vision. Pass a vision-capable --model (e.g. an OpenAI/Anthropic multimodal
# model) with the matching key; otherwise the agent server drops the images.
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
FILES=()
UPLOAD_FILES=0

usage() {
  cat >&2 <<'EOF'
Usage:
  oh-start.sh --prompt TEXT [--file FILE]... [--file-upload] [--repo URL] [--model ID] [--workdir PATH]

Options:
  --prompt TEXT      Task text. Optional if at least one --file is given.
  --file FILE        Attach a file (repeatable). Images are embedded in the
                     message; other files are inlined by default.
  --file-upload      Upload non-image files via POST /api/file/upload and
                     reference them by path, instead of inlining their contents.
  --repo URL         Repository for the agent to work in.
  --model ID         Override the default model. Use a vision model for images.
  --workdir PATH     Working directory on the agent host.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      PROMPT="${2:?--prompt requires text}"
      shift 2
      ;;
    --file|--md|--md-file|--context-file)
      FILES+=("${2:?$1 requires a path}")
      shift 2
      ;;
    --file-upload|--md-upload|--blob|--upload-md)
      UPLOAD_FILES=1
      shift
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

if [[ -z "$PROMPT" && ${#FILES[@]} -eq 0 ]]; then
  echo "Error: --prompt (or at least one --file) is required" >&2
  usage
  exit 1
fi

# Remember whether the caller supplied task text (the repo note below also
# fills PROMPT, but that is not a task instruction).
PROMPT_GIVEN=0
[[ -n "$PROMPT" ]] && PROMPT_GIVEN=1

if [[ ${#FILES[@]} -gt 0 ]]; then
  for f in "${FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
      echo "Error: --file not found: $f" >&2
      exit 1
    fi
  done
fi

if [[ -z "$SESSION_KEY" ]]; then
  echo "Error: OH_SESSION_API_KEYS_0 (or OH_SESSION_API_KEY) is required" >&2
  exit 1
fi

auth_headers=(
  -H "Content-Type: application/json"
  -H "Accept: application/json"
  -H "X-Session-API-Key: ${SESSION_KEY}"
  -H "Authorization: Bearer ${SESSION_KEY}"
)
# Multipart uploads set their own Content-Type (with boundary), so the
# JSON content type must be left out here.
upload_headers=(
  -H "Accept: application/json"
  -H "X-Session-API-Key: ${SESSION_KEY}"
  -H "Authorization: Bearer ${SESSION_KEY}"
)

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

inline_file() {
  local file="$1"
  printf '\n\n---\n# Attached document: %s\n\n' "$(basename "$file")"
  cat "$file"
  printf '\n'
}

# Map a file to an image MIME type, or nothing if it is treated as text.
image_mime() {
  case "${1,,}" in
    *.png) echo "image/png" ;;
    *.jpg|*.jpeg) echo "image/jpeg" ;;
    *.gif) echo "image/gif" ;;
    *.webp) echo "image/webp" ;;
    *.bmp) echo "image/bmp" ;;
    *.tif|*.tiff) echo "image/tiff" ;;
    *) echo "" ;;
  esac
}

image_urls_tmp="$(mktemp)"
image_json_tmp="$(mktemp)"
trap 'rm -f "$image_urls_tmp" "$image_json_tmp"' EXIT

IMAGE_FILES=()
uploaded_paths=()
added_text=0

# Attach files: embed images, inline or upload everything else.
if [[ ${#FILES[@]} -gt 0 ]]; then
  for f in "${FILES[@]}"; do
    mime="$(image_mime "$f")"
    if [[ -n "$mime" ]]; then
      IMAGE_FILES+=("$f")
      continue
    fi
    if [[ "$UPLOAD_FILES" -eq 1 ]]; then
      dest="${working_dir%/}/$(basename "$f")"
      enc_path="$(jq -rn --arg v "$dest" '$v|@uri')"
      if curl -fsS "${upload_headers[@]}" -F "file=@${f}" \
        "${AGENT_SERVER}/api/file/upload?path=${enc_path}" >/dev/null; then
        uploaded_paths+=("$dest")
      else
        echo "Warning: upload failed for $(basename "$f"); inlining it instead" >&2
        PROMPT="${PROMPT}$(inline_file "$f")"
        added_text=1
      fi
    else
      PROMPT="${PROMPT}$(inline_file "$f")"
      added_text=1
    fi
  done

  if [[ ${#uploaded_paths[@]} -gt 0 ]]; then
    PROMPT="${PROMPT}

---
Attached files (uploaded to the agent workspace):
$(printf -- '- %s\n' "${uploaded_paths[@]}")"
  fi

  if [[ ${#IMAGE_FILES[@]} -gt 0 ]]; then
    : > "$image_urls_tmp"
    names=""
    for img in "${IMAGE_FILES[@]}"; do
      mime="$(image_mime "$img")"
      size="$(wc -c < "$img" | tr -d '[:space:]')"
      if ((size > 5 * 1024 * 1024)); then
        echo "Warning: $(basename "$img") is $((size / 1024 / 1024))MiB; embedding it as a data URL may be slow or rejected" >&2
      fi
      { printf 'data:%s;base64,' "$mime"; base64 -w0 "$img"; printf '\n'; } >> "$image_urls_tmp"
      names="${names}$(basename "$img"), "
    done
    names="${names%, }"
    jq -R -s 'split("\n") | map(select(length > 0)) | map({type: "image", image_urls: [.]})' \
      "$image_urls_tmp" > "$image_json_tmp"
    PROMPT="${PROMPT}

The user attached ${#IMAGE_FILES[@]} image(s), in this order: ${names}."
    echo "Note: embedded images are only sent to vision-capable models; a text-only --model drops them silently." >&2
  fi
fi

# No task instruction was given: derive one from whatever was attached.
if [[ "$PROMPT_GIVEN" -eq 0 ]]; then
  if [[ ${#uploaded_paths[@]} -gt 0 && "$added_text" -eq 0 ]]; then
    PROMPT="Read the attached file(s) and carry out the task they describe.${PROMPT}"
  elif [[ "$added_text" -eq 0 && ${#IMAGE_FILES[@]} -gt 0 ]]; then
    PROMPT="Analyze the attached image(s).${PROMPT}"
  fi
fi

if [[ ! -s "$image_json_tmp" ]]; then
  printf '[]' > "$image_json_tmp"
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
  --slurpfile images "$image_json_tmp" \
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
        {name: "terminal"},
        {name: "file_editor"},
        {name: "task_tracker"}
      ],
      system_prompt_kwargs: {cli_mode: true}
    },
    workspace: {working_dir: $working_dir},
    initial_message: {
      role: "user",
      content: (
        [{type: "text", text: $prompt}]
        + ($images[0] // [])
      )
    },
    max_iterations: $max_iterations,
    stuck_detection: true,
    confirmation_policy: {kind: "NeverConfirm"}
  }')"

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

# The agent server may already start the conversation on create (409 on
# re-run); tolerate that silently rather than printing a confusing curl error.
curl -fsS "${auth_headers[@]}" -X POST "${AGENT_SERVER}/api/conversations/${CONV_ID}/run" >/dev/null 2>&1 || true

UI_URL="${UI_BASE}/conversations/${CONV_ID}"
echo "conversation_id=${CONV_ID}"
echo "$UI_URL"
