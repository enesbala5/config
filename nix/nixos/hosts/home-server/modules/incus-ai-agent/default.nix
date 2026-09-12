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
    ${lib.concatImapStringsSep "\n    " (
      i: origin: "Environment=OH_ALLOW_CORS_ORIGINS_${toString (i - 1)}=${origin}"
    ) cfg.corsOrigins}
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

  # With a pinned static IPv4 we can point proxies at the guest directly;
  # otherwise fall back to the wildcard connect address, which makes Incus
  # resolve the instance's current address from the bridge neighbour table
  # (NAT mode only).
  guestConnectIp = if cfg.network.staticIpv4 != null then cfg.network.staticIpv4 else "0.0.0.0";

  forwardDeviceName = fwd: "fwd-${fwd.protocol}-${toString fwd.hostPort}";

  desiredForwardDevices = lib.concatStringsSep " " (map forwardDeviceName cfg.network.portForwards);

  # Reconcile the profile's proxy devices. Profiles are stackable and this one
  # is used only by this instance, so it is the right home for host->guest
  # forwards (they then apply no matter how the VM is launched).
  portForwardScript = lib.concatMapStringsSep "\n" (
    fwd:
    let
      dev = forwardDeviceName fwd;
      listen = "${fwd.protocol}:${fwd.listenAddress}:${toString fwd.hostPort}";
      connect = "${fwd.protocol}:${guestConnectIp}:${toString fwd.guestPort}";
    in
    ''
      # `device get` requires a <key>; use `device list` for existence.
      dev=${lib.escapeShellArg dev}
      if incus profile device list "$profile" | grep -Fxq "$dev"; then
        incus profile device set "$profile" "$dev" listen=${lib.escapeShellArg listen} connect=${lib.escapeShellArg connect} nat=true
      else
        incus profile device add "$profile" "$dev" proxy listen=${lib.escapeShellArg listen} connect=${lib.escapeShellArg connect} nat=true
      fi
    ''
  ) cfg.network.portForwards;

  # Drop forwards we own but no longer declare, so removing one from the Nix
  # config actually removes the proxy device.
  prunePortForwardScript = ''
    # `incus profile device list` prints one name per line; it has no --format.
    for dev in $(incus profile device list "$profile"); do
      case "$dev" in
        fwd-*)
          case " ${desiredForwardDevices} " in
            *" $dev "*) ;;
            *) incus profile device remove "$profile" "$dev" ;;
          esac
          ;;
      esac
    done
  '';

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

    # Browser origin of the OpenHands UI. Without this, a split-host UI
    # (agent.enesbala.com → agent-api.enesbala.com) gets 400 Disallowed CORS origin.
    corsOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "https://agent.enesbala.com" ];
      description = ''
        Origins allowed to call the Agent Server from a browser
        (`OH_ALLOW_CORS_ORIGINS_*`). Localhost is always allowed by the
        server; this list is for the hosted UI origin.
      '';
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

      portForwards = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              protocol = lib.mkOption {
                type = lib.types.enum [
                  "tcp"
                  "udp"
                ];
                default = "tcp";
              };
              hostPort = lib.mkOption {
                type = lib.types.port;
                description = "Port on the home server to listen on and forward from.";
              };
              guestPort = lib.mkOption {
                type = lib.types.port;
                description = "Port inside the guest to forward to.";
              };
              listenAddress = lib.mkOption {
                type = lib.types.str;
                # Incus rejects wildcards for proxy devices with nat=true (required for VMs).
                default = "192.168.0.40";
                description = "Host address to bind the listener to (must be a concrete host IP; NAT mode forbids 0.0.0.0).";
              };
            };
          }
        );
        default = [ ];
        description = ''
          Host->guest port forwards, implemented as Incus proxy devices in NAT
          mode (the only mode VMs support). Devices are named fwd-<proto>-<port>
          and reconciled against this list on every activation.
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
        pkgs.gnugrep
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
        # Static IP must exist before NAT proxies (connect IP must be a static
        # address on the instance).
        ${staticIpScript}
        ${portForwardScript}
        ${prunePortForwardScript}
      '';
    };
  };
}
