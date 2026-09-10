{
  config,
  lib,
  pkgs,
  data,
  ...
}:

let
  cfg = config.homeServer.incusAiAgent;

  telegramScriptContent = builtins.readFile "${data.configDirectory}/tools/telegram/notify.sh";
  ohStartScriptContent = builtins.readFile "${data.configDirectory}/tools/incus/oh-start.sh";

  yamlIndent =
    n: text:
    let
      pad = lib.concatStrings (lib.genList (_: " ") n);
    in
    lib.concatMapStringsSep "\n" (line: pad + line) (lib.splitString "\n" text);

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
    ExecStart=/opt/oh-agent-server/bin/python -m openhands.agent_server --host 0.0.0.0 --port 8000
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
    "  - path: /usr/local/bin/oh-start.sh"
    "    permissions: '0755'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 ohStartScriptContent)
    ""
    "  - path: /etc/systemd/system/openhands-agent-server.service"
    "    permissions: '0644'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 agentServerUnit)
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
    "  - 'grep -q /usr/local/bin /etc/environment || echo PATH=\"/usr/local/bin:/root/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin\" >> /etc/environment'"
    "  - \"uv venv /opt/oh-agent-server --python 3.12\""
    "  - \"/root/.local/bin/uv pip install --python /opt/oh-agent-server/bin/python -U openhands-sdk openhands-tools openhands-workspace openhands-agent-server\""
    "  - systemctl daemon-reload"
    "  - systemctl enable --now openhands-agent-server.service"
  ];

  userDataPath = "/etc/incus-profiles/${cfg.profileName}/user-data";
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
    users.users.${data.username}.extraGroups = [ "incus-admin" ];

    # Limits only. Cloud-init user-data is applied by the oneshot below so
    # nested YAML cannot fail incus-preseed.service for the whole host.
    virtualisation.incus.preseed.profiles = [
      {
        name = cfg.profileName;
        config = {
          "limits.cpu" = cfg.limits.cpu;
          "limits.memory" = cfg.limits.memory;
          "security.nesting" = "true";
        };
      }
    ];

    environment.etc."incus-profiles/${cfg.profileName}/user-data" = {
      text = cloudInitUserData;
      mode = "0644";
    };

    systemd.services."incus-profile-${cfg.profileName}" = {
      description = "Ensure Incus profile ${cfg.profileName} exists";
      after = [
        "incus.service"
        "incus-preseed.service"
      ];
      wants = [ "incus.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.incus
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        profile=${lib.escapeShellArg cfg.profileName}
        if ! incus profile show "$profile" >/dev/null 2>&1; then
          incus profile create "$profile"
        fi
        incus profile set "$profile" limits.cpu ${lib.escapeShellArg cfg.limits.cpu}
        incus profile set "$profile" limits.memory ${lib.escapeShellArg cfg.limits.memory}
        incus profile set "$profile" security.nesting true
        incus profile set "$profile" cloud-init.user-data - < ${lib.escapeShellArg userDataPath}
        incus profile set "$profile" user.user-data - < ${lib.escapeShellArg userDataPath}
      '';
    };
  };
}
