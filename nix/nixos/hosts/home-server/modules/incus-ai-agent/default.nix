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
  canvasStartScriptContent = builtins.readFile "${data.configDirectory}/tools/incus/agent-canvas-start.sh";

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

  # Agent Canvas is the browser client (OpenHands/OpenHands) that replaced the
  # legacy all-in-one OpenHands GUI. It runs frontend-only so the existing
  # openhands-agent-server on :8000 stays the single execution backend; the
  # frontend is served on cfg.frontendPort and proxied by the host Caddy.
  agentCanvasUnit = ''
    [Unit]
    Description=OpenHands Agent Canvas frontend (browser client)
    After=network-online.target openhands-agent-server.service
    Wants=network-online.target
    Requires=openhands-agent-server.service

    [Service]
    Type=simple
    EnvironmentFile=-/etc/agent-env
    Environment=HOME=/root
    Environment=PATH=/usr/local/bin:/root/.local/bin:/usr/bin
    Environment=CANVAS_PORT=${toString cfg.frontendPort}
    WorkingDirectory=/var/lib/ai-agent
    ExecStart=/usr/local/bin/agent-canvas-start.sh
    Restart=on-failure
    RestartSec=10

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
    "  - path: /usr/local/bin/agent-canvas-start.sh"
    "    permissions: '0755'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 canvasStartScriptContent)
    ""
    "  - path: /etc/systemd/system/openhands-agent-server.service"
    "    permissions: '0644'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 agentServerUnit)
    ""
    "  - path: /etc/systemd/system/openhands-agent-canvas.service"
    "    permissions: '0644'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 agentCanvasUnit)
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
    ""
    "  # Agent Canvas frontend. Node 22.x comes from NodeSource (Ubuntu 24.04's"
    "  # nodejs is 18.x, below the 22.12 floor)."
    "  - \"curl -fsSL https://deb.nodesource.com/setup_22.x | bash -\""
    "  - apt-get install -y nodejs"
    "  - npm install -g @openhands/agent-canvas"
    "  - npm cache clean --force || true"
    "  - systemctl enable --now openhands-agent-canvas.service"
  ];

  userDataPath = "/etc/incus-profiles/${cfg.profileName}/user-data";

  # Pin the guest IP via an instance-level override of the profile-provided NIC.
  # Skipped when the instance does not exist yet; the launch helper applies it
  # before first boot instead.
  staticIpScript = lib.optionalString (cfg.network.staticIpv4 != null) ''
    if incus info "$instance" >/dev/null 2>&1; then
      current_ip=$(incus config device get "$instance" ${lib.escapeShellArg cfg.network.nic} ipv4.address 2>/dev/null || true)
      if [ "$current_ip" != ${lib.escapeShellArg cfg.network.staticIpv4} ]; then
        # eth0 comes from the default profile; `set` only works after a local
        # override exists.
        if ! incus config device set "$instance" ${lib.escapeShellArg cfg.network.nic} ipv4.address=${lib.escapeShellArg cfg.network.staticIpv4} 2>/dev/null; then
          incus config device override "$instance" ${lib.escapeShellArg cfg.network.nic} ipv4.address=${lib.escapeShellArg cfg.network.staticIpv4}
        fi
      fi
    fi
  '';
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

    frontendPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = ''
        Guest port for the Agent Canvas frontend (browser client). Kept off
        8000, which the openhands-agent-server backend owns, so both can run
        at once. The host Caddy reverse-proxies agent.enesbala.com here.
      '';
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

    network = {
      nic = lib.mkOption {
        type = lib.types.str;
        default = "eth0";
        description = "Guest NIC to pin the static IPv4 address on.";
      };

      staticIpv4 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "10.0.100.173";
        description = ''
          Static IPv4 address for the VM, inside the incusbr0 subnet
          (10.0.100.0/24). Assigned by the managed bridge's DHCP server.
        '';
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
        instance=${lib.escapeShellArg cfg.vmName}
        profile=${lib.escapeShellArg cfg.profileName}
        if ! incus profile show "$profile" >/dev/null 2>&1; then
          incus profile create "$profile"
        fi
        incus profile set "$profile" limits.cpu ${lib.escapeShellArg cfg.limits.cpu}
        incus profile set "$profile" limits.memory ${lib.escapeShellArg cfg.limits.memory}
        incus profile set "$profile" security.nesting true
        incus profile set "$profile" cloud-init.user-data - < ${lib.escapeShellArg userDataPath}
        incus profile set "$profile" user.user-data - < ${lib.escapeShellArg userDataPath}
        ${staticIpScript}
      '';
    };
  };
}
