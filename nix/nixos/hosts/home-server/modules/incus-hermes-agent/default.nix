{
  config,
  lib,
  pkgs,
  data,
  ...
}:

let
  cfg = config.homeServer.incusHermesAgent;

  telegramScriptContent = builtins.readFile "${data.configDirectory}/tools/telegram/notify.sh";
  ohStartScriptContent = builtins.readFile "${data.configDirectory}/tools/incus/oh-start.sh";

  yamlIndent =
    n: text:
    let
      pad = lib.concatStrings (lib.genList (_: " ") n);
    in
    lib.concatMapStringsSep "\n" (line: pad + line) (lib.splitString "\n" text);

  hermesServiceUnit = ''
    [Unit]
    Description=Hermes Agent messaging gateway
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    Environment=HOME=/root
    WorkingDirectory=/root
    ExecStart=/bin/bash -lc 'set -a && source /etc/hermes-env && set +a; export PATH=/usr/local/bin:/root/.local/bin:$PATH; exec hermes gateway'
    Restart=on-failure
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
  '';

  hermesDashboardUnit = ''
    [Unit]
    Description=Hermes Agent web dashboard
    After=network-online.target hermes-agent.service
    Wants=network-online.target

    [Service]
    Type=simple
    Environment=HOME=/root
    Environment=HERMES_DASHBOARD_PUBLIC_URL=https://hermes.enesbala.com
    WorkingDirectory=/root
    ExecStart=/bin/bash -lc 'set -a && source /etc/hermes-env && set +a; export PATH=/usr/local/bin:/root/.local/bin:$PATH; exec hermes dashboard --host 0.0.0.0 --port 9119 --no-open'
    Restart=on-failure
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
  '';

  hermesEnvProfile = ''
    # Export /etc/hermes-env for Hermes CLI and login shells (incus exec bash -l).
    if [ -f /etc/hermes-env ]; then
      set -a
      # shellcheck disable=SC1091
      . /etc/hermes-env
      set +a
    fi
  '';

  seedSoul = ''
    Coding goes to OpenHands on this host, not to you.

    Start:
    /usr/local/bin/oh-start.sh --prompt "..." [--repo URL]
    or POST http://byok-agent.incus:8000/api/conversations
    header X-Session-API-Key: $OH_SESSION_API_KEY

    Then send the user:
    https://agent.enesbala.com/conversations/<id>

    Do not run coding agents locally. Do not wrap or translate OpenHands events.
  '';

  cloudInitUserData = lib.concatStringsSep "\n" [
    "#cloud-config"
    "package_update: true"
    "packages:"
    "  - git"
    "  - curl"
    "  - jq"
    "  - ca-certificates"
    "  - python3"
    "  - python3-venv"
    "  - python3-pip"
    "  - chromium-browser"
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
    "  - path: /etc/systemd/system/hermes-agent.service"
    "    permissions: '0644'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 hermesServiceUnit)
    ""
    "  - path: /etc/systemd/system/hermes-dashboard.service"
    "    permissions: '0644'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 hermesDashboardUnit)
    ""
    "  - path: /etc/profile.d/hermes-env.sh"
    "    permissions: '0644'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 hermesEnvProfile)
    ""
    "  - path: /var/lib/hermes/SOUL.seed.md"
    "    permissions: '0644'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 seedSoul)
    ""
    "runcmd:"
    "  - mkdir -p /root/.hermes /var/lib/hermes/scratch"
    "  - chmod 700 /root/.hermes /var/lib/hermes"
    "  - \"export HOME=/root; curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash\""
    # Root FHS installs already place the launcher at /usr/local/bin/hermes.
    # Do not overwrite it with ~/.local/bin (that path is unused and dangling).
    "  - test -x /usr/local/bin/hermes || ln -sfn /usr/local/lib/hermes-agent/venv/bin/hermes /usr/local/bin/hermes"
    "  - test -f /root/.hermes/SOUL.md || cp /var/lib/hermes/SOUL.seed.md /root/.hermes/SOUL.md || true"
    "  - systemctl daemon-reload"
    "  - systemctl enable hermes-agent.service"
    "  - systemctl enable hermes-dashboard.service"
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
  options.homeServer.incusHermesAgent = {
    enable = lib.mkEnableOption "persistent Hermes Agent Incus VM (profile + host helpers)";

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "hermes-agent";
    };

    profileName = lib.mkOption {
      type = lib.types.str;
      default = "hermes-agent";
    };

    limits = {
      cpu = lib.mkOption {
        type = lib.types.str;
        default = "2";
      };
      memory = lib.mkOption {
        type = lib.types.str;
        default = "4GiB";
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
        example = "10.0.100.174";
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

    # Limits only. Full cloud-init user-data is nested YAML and breaks
    # `incus admin init --preseed` on an already-initialized daemon, which
    # left the profile missing at launch time.
    virtualisation.incus.preseed.profiles = [
      {
        name = cfg.profileName;
        config = {
          "limits.cpu" = cfg.limits.cpu;
          "limits.memory" = cfg.limits.memory;
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
