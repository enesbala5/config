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
    CACHE_DIR="''${CACHE_DIR:-/var/lib/ai-agent/cache}"
    MODEL="''${MODEL:-''${DEFAULT_MODEL:-deepseek/deepseek-chat}}"

    mkdir -p "$WORKSPACE_DIR" "$LOG_DIR" "$CACHE_DIR"
    LOG_FILE="$LOG_DIR/$(date +%Y%m%d-%H%M%S).log"
    touch "$LOG_FILE"
    chmod 0600 "$LOG_FILE"

    if [[ -n "''${GITHUB_TOKEN:-}" ]]; then
      git config --global url."https://x-access-token:''${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
    fi

    REPO_LABEL="''${REPO:-none}"
    HOST_LABEL="$(hostname)"

    /usr/local/bin/notify.sh -m md "BYOK Agent Task Started\nHost: ''${HOST_LABEL}\nRepo: ''${REPO_LABEL}\nModel: ''${MODEL}" || true

    cd "$WORKSPACE_DIR"
    if [[ -n "$REPO" ]]; then
      REPO_NAME="$(basename "$REPO" .git)"
      if [[ -d "$REPO_NAME/.git" ]]; then
        cd "$REPO_NAME"
        git fetch --all || true
        git pull --ff-only || true
      else
        git clone "$REPO" "$REPO_NAME"
        cd "$REPO_NAME"
      fi
    elif [[ -n "$WORKDIR" ]]; then
      cd "$WORKDIR"
    fi

    export DEEPSEEK_API_KEY="''${DEEPSEEK_API_KEY:-}"
    export LLM_API_KEY="''${LLM_API_KEY:-''${DEEPSEEK_API_KEY:-}}"
    export LLM_MODEL="''${LLM_MODEL:-$MODEL}"
    export LLM_BASE_URL="''${LLM_BASE_URL:-https://api.deepseek.com}"
    export OPENHANDS_SUPPRESS_BANNER=1

    EXIT_CODE=0
    set +e
    if command -v openhands >/dev/null 2>&1; then
      openhands --headless --override-with-envs --always-approve --exit-without-confirmation -t "$PROMPT" > >(tee -a "$LOG_FILE") 2>&1
      EXIT_CODE=$?
    else
      echo "Error: openhands not found in PATH" | tee -a "$LOG_FILE" >&2
      EXIT_CODE=127
    fi
    set -e

    if [[ "$EXIT_CODE" -eq 0 ]]; then
      /usr/local/bin/notify.sh -m md "BYOK Agent Task Finished\nHost: ''${HOST_LABEL}\nRepo: ''${REPO_LABEL}\nModel: ''${MODEL}" || true
    else
      /usr/local/bin/notify.sh -m md "BYOK Agent Task Failed\nHost: ''${HOST_LABEL}\nRepo: ''${REPO_LABEL}\nModel: ''${MODEL}\nExit: ''${EXIT_CODE}" || true
    fi

    exit "$EXIT_CODE"
  '';

  taskApiUnit = ''
    [Unit]
    Description=OpenHands REST task API for Hermes
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    EnvironmentFile=-/etc/agent-env
    Environment=HOME=/root
    Environment=PATH=/usr/local/bin:/root/.local/bin:/usr/bin
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
    "  - mkdir -p /var/lib/ai-agent/workspace /var/lib/ai-agent/cache /var/lib/ai-agent/logs"
    "  - chmod 700 /var/lib/ai-agent"
    "  - chmod 755 /var/lib/ai-agent/workspace /var/lib/ai-agent/cache /var/lib/ai-agent/logs"
    "  - systemctl enable --now docker || true"
    "  - \"curl -LsSf https://astral.sh/uv/install.sh | sh\""
    "  - ln -sfn /root/.local/bin/uv /usr/local/bin/uv || true"
    "  - ln -sfn /root/.local/bin/uvx /usr/local/bin/uvx || true"
    "  - \"grep -q /usr/local/bin /etc/environment || echo PATH=\"/usr/local/bin:/root/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin\" >> /etc/environment\""
    "  - \"curl -fsSL https://install.openhands.dev/install.sh | sh\""
    "  - ln -sfn /root/.local/bin/openhands /usr/local/bin/openhands || true"
    "  - \"command -v openhands || (export PATH=/usr/local/bin:/root/.local/bin:$PATH && uv tool install openhands --python 3.12 && ln -sfn /root/.local/bin/openhands /usr/local/bin/openhands)\""
    "  - systemctl daemon-reload"
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
