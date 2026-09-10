{
  config,
  lib,
  data,
  ...
}:

let
  cfg = config.homeServer.incusAiAgent;

  telegramScriptContent = builtins.readFile "${data.configDirectory}/tools/telegram/notify.sh";
  taskApiScriptContent = builtins.readFile "${data.configDirectory}/tools/incus/openhands-task-api.py";

  yamlIndent =
    n: text:
    let
      pad = lib.concatStrings (lib.genList (_: " ") n);
    in
    lib.concatMapStringsSep "\n" (line: pad + line) (lib.splitString "\n" text);

  guestRunAgentTaskScript = ''
    #!/usr/bin/env bash
    set -euo pipefail

    REPO=""
    PROMPT=""
    MODEL=""
    WORKDIR=""
    WAIT="1"

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --repo)
          REPO="''${2:?--repo requires a URL}"
          shift 2
          ;;
        --prompt)
          PROMPT="''${2:?--prompt requires text}"
          shift 2
          ;;
        --model)
          MODEL="''${2:?--model requires an id}"
          shift 2
          ;;
        --workdir)
          WORKDIR="''${2:?--workdir requires a path}"
          shift 2
          ;;
        --no-wait)
          WAIT="0"
          shift
          ;;
        *)
          echo "Unknown argument: $1" >&2
          exit 1
          ;;
      esac
    done

    if [[ -z "$PROMPT" ]]; then
      echo "Error: --prompt is required" >&2
      exit 1
    fi

    if [[ ! -f /etc/agent-env ]]; then
      echo "Error: /etc/agent-env missing (host must push secrets before tasks)" >&2
      exit 1
    fi

    set -o allexport
    # shellcheck disable=SC1091
    source /etc/agent-env
    set +o allexport

    export PATH="/usr/local/bin:/root/.local/bin:''${PATH}"

    WORKSPACE_DIR="''${WORKSPACE_DIR:-/var/lib/ai-agent/workspace}"
    LOG_DIR="''${LOG_DIR:-/var/lib/ai-agent/logs}"
    MODEL="''${MODEL:-''${DEFAULT_MODEL:-deepseek/deepseek-chat}}"
    ORCH_URL="''${OPENHANDS_TASK_API_URL:-http://127.0.0.1:8090}"

    mkdir -p "$WORKSPACE_DIR" "$LOG_DIR"
    LOG_FILE="$LOG_DIR/$(date +%Y%m%d-%H%M%S).log"
    touch "$LOG_FILE"
    chmod 0600 "$LOG_FILE"

    if [[ -n "''${GITHUB_TOKEN:-}" ]]; then
      git config --global url."https://x-access-token:''${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
    fi

    REPO_LABEL="''${REPO:-none}"
    HOST_LABEL="$(hostname)"

    /usr/local/bin/notify.sh -m md "BYOK Agent Task Started\nHost: ''${HOST_LABEL}\nRepo: ''${REPO_LABEL}\nModel: ''${MODEL}" || true

    if ! curl -fsS "''${ORCH_URL}/health" >/dev/null; then
      echo "Error: OpenHands orchestrator is not healthy at ''${ORCH_URL}" | tee -a "$LOG_FILE" >&2
      systemctl status openhands-agent-server --no-pager || true
      systemctl status openhands-task-api --no-pager || true
      exit 1
    fi

    BODY="$(jq -n --arg prompt "$PROMPT" --arg repo "$REPO" --arg model "$MODEL" --arg workdir "$WORKDIR" '{
      prompt: $prompt,
      repo: $repo,
      model: (if $model == "" then null else $model end),
      workdir: $workdir
    }')"

    RESPONSE="$(curl -fsS -X POST "''${ORCH_URL}/tasks" -H "Content-Type: application/json" -d "$BODY" | tee -a "$LOG_FILE")"
    JOB_ID="$(printf '%s' "$RESPONSE" | jq -r '.conversation_id // .job_id')"
    if [[ -z "$JOB_ID" || "$JOB_ID" == "null" ]]; then
      echo "Error: orchestrator did not return a conversation id" | tee -a "$LOG_FILE" >&2
      /usr/local/bin/notify.sh -m md "BYOK Agent Task Failed\nHost: ''${HOST_LABEL}\nRepo: ''${REPO_LABEL}\nMissing conversation id" || true
      exit 1
    fi

    if [[ "$WAIT" != "1" ]]; then
      echo "conversation_id=''${JOB_ID}"
      exit 0
    fi

    EXIT_CODE=0
    STATUS=""
    for _ in $(seq 1 360); do
      STATUS_JSON="$(curl -fsS "''${ORCH_URL}/tasks/''${JOB_ID}" || true)"
      printf '%s\n' "$STATUS_JSON" >> "$LOG_FILE"
      STATUS="$(printf '%s' "$STATUS_JSON" | jq -r '.status // empty')"
      case "$STATUS" in
        ok|finished)
          EXIT_CODE=0
          break
          ;;
        failed|error)
          EXIT_CODE=1
          break
          ;;
        cancelled|paused)
          EXIT_CODE=0
          break
          ;;
      esac
      sleep 5
    done

    if [[ "$STATUS" != "ok" && "$STATUS" != "finished" && "$STATUS" != "cancelled" && "$STATUS" != "paused" && "$STATUS" != "failed" && "$STATUS" != "error" ]]; then
      echo "Error: timed out waiting for conversation ''${JOB_ID}" | tee -a "$LOG_FILE" >&2
      EXIT_CODE=1
    fi

    if [[ "$EXIT_CODE" -eq 0 ]]; then
      /usr/local/bin/notify.sh -m md "BYOK Agent Task Finished\nHost: ''${HOST_LABEL}\nRepo: ''${REPO_LABEL}\nModel: ''${MODEL}\nConversation: ''${JOB_ID}" || true
    else
      /usr/local/bin/notify.sh -m md "BYOK Agent Task Failed\nHost: ''${HOST_LABEL}\nRepo: ''${REPO_LABEL}\nModel: ''${MODEL}\nConversation: ''${JOB_ID}" || true
    fi

    exit "$EXIT_CODE"
  '';

  agentServerUnit = ''
    [Unit]
    Description=OpenHands Agent Server (conversation runtime)
    After=network-online.target docker.service
    Wants=network-online.target

    [Service]
    Type=simple
    EnvironmentFile=-/etc/agent-env
    Environment=HOME=/root
    Environment=PATH=/opt/oh-agent-server/bin:/usr/local/bin:/root/.local/bin:/usr/bin
    WorkingDirectory=/var/lib/ai-agent
    ExecStart=/opt/oh-agent-server/bin/python -m openhands.agent_server --host 127.0.0.1 --port 8000
    Restart=on-failure
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
  '';

  taskApiUnit = ''
    [Unit]
    Description=OpenHands orchestrator API for Hermes
    After=network-online.target openhands-agent-server.service
    Wants=network-online.target
    Requires=openhands-agent-server.service

    [Service]
    Type=simple
    EnvironmentFile=-/etc/agent-env
    Environment=HOME=/root
    Environment=PATH=/usr/local/bin:/root/.local/bin:/usr/bin
    Environment=OPENHANDS_AGENT_SERVER_URL=http://127.0.0.1:8000
    ExecStart=/usr/bin/python3 /usr/local/bin/openhands-task-api.py
    Restart=on-failure
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
  '';

  cloudInitUserData = lib.concatStringsSep "\n" [
    "#cloud-config"
    "package_update: true"
    "packages:"
    "  - git"
    "  - curl"
    "  - jq"
    "  - ca-certificates"
    "  - build-essential"
    "  - python3"
    "  - python3-venv"
    "  - python3-pip"
    "  - docker.io"
    ""
    "write_files:"
    "  - path: /usr/local/bin/notify.sh"
    "    permissions: '0755'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 telegramScriptContent)
    ""
    "  - path: /usr/local/bin/guest-run-agent-task.sh"
    "    permissions: '0755'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 guestRunAgentTaskScript)
    ""
    "  - path: /usr/local/bin/openhands-task-api.py"
    "    permissions: '0755'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 taskApiScriptContent)
    ""
    "  - path: /etc/systemd/system/openhands-agent-server.service"
    "    permissions: '0644'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 agentServerUnit)
    ""
    "  - path: /etc/systemd/system/openhands-task-api.service"
    "    permissions: '0644'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 taskApiUnit)
    ""
    "  - path: /etc/profile.d/uv.sh"
    "    permissions: '0644'"
    "    owner: root:root"
    "    content: |"
    "      export PATH=\"/usr/local/bin:/root/.local/bin:$PATH\""
    ""
    "runcmd:"
    "  - mkdir -p /var/lib/ai-agent/workspace /var/lib/ai-agent/cache /var/lib/ai-agent/logs /opt/oh-agent-server"
    "  - chmod 700 /var/lib/ai-agent"
    "  - chmod 755 /var/lib/ai-agent/workspace /var/lib/ai-agent/cache /var/lib/ai-agent/logs"
    "  - systemctl enable --now docker || true"
    "  - \"curl -LsSf https://astral.sh/uv/install.sh | sh\""
    "  - ln -sfn /root/.local/bin/uv /usr/local/bin/uv || true"
    "  - ln -sfn /root/.local/bin/uvx /usr/local/bin/uvx || true"
    "  - \"grep -q /usr/local/bin /etc/environment || echo PATH=\"/usr/local/bin:/root/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin\" >> /etc/environment\""
    "  - \"uv venv /opt/oh-agent-server --python 3.12\""
    "  - \"/root/.local/bin/uv pip install --python /opt/oh-agent-server/bin/python -U openhands-sdk openhands-tools openhands-workspace openhands-agent-server\""
    "  - \"curl -fsSL https://install.openhands.dev/install.sh | sh\""
    "  - ln -sfn /root/.local/bin/openhands /usr/local/bin/openhands || true"
    "  - systemctl daemon-reload"
    "  - systemctl enable --now openhands-agent-server.service"
    "  - systemctl enable --now openhands-task-api.service"
  ];
in
{
  options.homeServer.incusAiAgent = {
    enable = lib.mkEnableOption "persistent BYOK Incus AI agent VM (profile + host helpers)";

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "byok-agent";
    };

    profileName = lib.mkOption {
      type = lib.types.str;
      default = "byok-agent";
    };

    limits = {
      cpu = lib.mkOption {
        type = lib.types.str;
        default = "4";
      };
      memory = lib.mkOption {
        type = lib.types.str;
        default = "8GiB";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${data.username}.extraGroups = [ "incus-admin" ];

    virtualisation.incus.preseed.profiles = [
      {
        name = cfg.profileName;
        config = {
          "limits.cpu" = cfg.limits.cpu;
          "limits.memory" = cfg.limits.memory;
          "security.nesting" = "true";
          "user.user-data" = cloudInitUserData;
          "cloud-init.user-data" = cloudInitUserData;
        };
      }
    ];
  };
}
