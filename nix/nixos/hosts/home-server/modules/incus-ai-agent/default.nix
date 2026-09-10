{
  config,
  lib,
  data,
  ...
}:

let
  cfg = config.homeServer.incusAiAgent;

  telegramScriptContent = builtins.readFile "${data.configDirectory}/tools/telegram/notify.sh";

  # Indent every line for a YAML `|` block (avoids Nix '' indent-strip
  # mangling multi-line interpolations).
  yamlIndent =
    n: text:
    let
      pad = lib.concatStrings (lib.genList (_: " ") n);
    in
    lib.concatMapStringsSep "\n" (line: pad + line) (lib.splitString "\n" text);

  guestRunAgentTaskScript = ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Guest task runner for the BYOK Incus agent VM.
    # Args:
    #   --repo URL          optional; clone or update under WORKSPACE_DIR/<name>
    #   --prompt TEXT       required task text
    #   --model ID          optional override of DEFAULT_MODEL
    #   --workdir PATH      optional existing directory (used when --repo omitted)

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

    WORKSPACE_DIR="''${WORKSPACE_DIR:-/var/lib/ai-agent/workspace}"
    LOG_DIR="''${LOG_DIR:-/var/lib/ai-agent/logs}"
    CACHE_DIR="''${CACHE_DIR:-/var/lib/ai-agent/cache}"
    MODEL="''${MODEL:-''${DEFAULT_MODEL:-deepseek/deepseek-chat}}"

    mkdir -p "$WORKSPACE_DIR" "$LOG_DIR" "$CACHE_DIR"
    LOG_FILE="$LOG_DIR/$(date +%Y%m%d-%H%M%S).log"
    touch "$LOG_FILE"
    chmod 0600 "$LOG_FILE"

    # Git HTTPS auth from fine-grained PAT (never echo the token).
    if [[ -n "''${GITHUB_TOKEN:-}" ]]; then
      git config --global url."https://x-access-token:''${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"
    fi

    REPO_LABEL="''${REPO:-none}"
    HOST_LABEL="$(hostname)"

    /usr/local/bin/notify.sh -m md "🤖 *BYOK Agent Task Started*
    🖥️ Host: \`''${HOST_LABEL}\`
    📦 Repo: \`''${REPO_LABEL}\`
    🧠 Model: \`''${MODEL}\`" || true

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

    # Map DeepSeek BYOK into common harness env names (never log values).
    export DEEPSEEK_API_KEY="''${DEEPSEEK_API_KEY:-}"
    export LLM_API_KEY="''${LLM_API_KEY:-''${DEEPSEEK_API_KEY:-}}"
    export LLM_MODEL="''${LLM_MODEL:-$MODEL}"
    export LLM_BASE_URL="''${LLM_BASE_URL:-https://api.deepseek.com}"

    EXIT_CODE=0
    set +e
    if command -v opencode >/dev/null 2>&1; then
      opencode run -m "$MODEL" --dangerously-skip-permissions "$PROMPT" > >(tee -a "$LOG_FILE") 2>&1
      EXIT_CODE=$?
    elif command -v openhands >/dev/null 2>&1; then
      openhands --headless --override-with-envs -t "$PROMPT" > >(tee -a "$LOG_FILE") 2>&1
      EXIT_CODE=$?
    else
      echo "Error: neither opencode nor openhands found in PATH" | tee -a "$LOG_FILE" >&2
      EXIT_CODE=127
    fi
    set -e

    if [[ "$EXIT_CODE" -eq 0 ]]; then
      /usr/local/bin/notify.sh -m md "✅ *BYOK Agent Task Finished*
    🖥️ Host: \`''${HOST_LABEL}\`
    📦 Repo: \`''${REPO_LABEL}\`
    🧠 Model: \`''${MODEL}\`" || true
    else
      /usr/local/bin/notify.sh -m md "❌ *BYOK Agent Task Failed*
    🖥️ Host: \`''${HOST_LABEL}\`
    📦 Repo: \`''${REPO_LABEL}\`
    🧠 Model: \`''${MODEL}\`
    🔢 Exit: \`''${EXIT_CODE}\`" || true
    fi

    exit "$EXIT_CODE"
  '';

  # Built as a list so interpolated scripts do not fight Nix '' indent stripping.
  cloudInitUserData = lib.concatStringsSep "\n" [
    "#cloud-config"
    "package_update: true"
    "packages:"
    "  - git"
    "  - curl"
    "  - jq"
    "  - ca-certificates"
    "  - build-essential"
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
    "runcmd:"
    "  - mkdir -p /var/lib/ai-agent/workspace /var/lib/ai-agent/cache /var/lib/ai-agent/logs"
    "  - chmod 700 /var/lib/ai-agent"
    "  - chmod 755 /var/lib/ai-agent/workspace /var/lib/ai-agent/cache /var/lib/ai-agent/logs"
    "  - systemctl enable --now docker || true"
    # Quote the pipe: unquoted `|` is a YAML literal-block indicator and
    # can make cloud-init parse/run this runcmd incorrectly.
    "  - \"curl -fsSL https://opencode.ai/install | bash\""
  ];
in
{
  options.homeServer.incusAiAgent = {
    enable = lib.mkEnableOption "persistent BYOK Incus AI agent VM (profile + host helpers)";

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "byok-agent";
      description = "Persistent Incus VM instance name";
    };

    profileName = lib.mkOption {
      type = lib.types.str;
      default = "byok-agent";
      description = "Incus profile name providing cloud-init + limits";
    };

    limits = {
      cpu = lib.mkOption {
        type = lib.types.str;
        default = "4";
        description = "Incus limits.cpu for the agent profile";
      };

      memory = lib.mkOption {
        type = lib.types.str;
        default = "8GiB";
        description = "Incus limits.memory for the agent profile";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Interactive user can run incus (root already has incus-admin on this host).
    users.users.${data.username}.extraGroups = [ "incus-admin" ];

    # Append alongside the existing default profile — do not replace it.
    # Workspace lives on the VM root disk under /var/lib/ai-agent (default
    # profile root is already ≥35GiB on this host). Extra HDD bind mounts
    # can be added later if clones should survive golden restores.
    virtualisation.incus.preseed.profiles = [
      {
        name = cfg.profileName;
        config = {
          "limits.cpu" = cfg.limits.cpu;
          "limits.memory" = cfg.limits.memory;
          # OpenHands (and optional Docker runtime) need nesting.
          "security.nesting" = "true";
          "user.user-data" = cloudInitUserData;
          "cloud-init.user-data" = cloudInitUserData;
        };
      }
    ];
  };
}
