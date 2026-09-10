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
    EnvironmentFile=-/etc/hermes-env
    Environment=HOME=/root
    WorkingDirectory=/root
    ExecStart=/bin/bash -lc 'export PATH=/usr/local/bin:/root/.local/bin:$PATH; exec hermes gateway'
    Restart=on-failure
    RestartSec=10

    [Install]
    WantedBy=multi-user.target
  '';

  seedSoul = ''
    You run on a dedicated Incus VM (hermes-agent) on home-server.

    Coding work that needs a sandboxed toolchain should go through the
    coding-bridge MCP tool (`trigger_coding_task`) rather than being done
    in this VM. This VM holds memory, skills, Telegram, and scheduling.

    Repo conventions for enesbala5/config:
    - NixOS + agenix. Secrets live in nix/secrets and are created with manage-secret.
    - Never paste tokens into chat. Never write secrets into ~/.hermes memory.
    - Host notify uses OPS_TELEGRAM_* ; your own channel uses TELEGRAM_BOT_TOKEN.
    - Keep working copies in /var/lib/hermes/scratch, not in secret-bearing trees.
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
    "  - path: /etc/systemd/system/hermes-agent.service"
    "    permissions: '0644'"
    "    owner: root:root"
    "    content: |"
    (yamlIndent 6 hermesServiceUnit)
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
    "  - \"curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash\""
    "  - ln -sfn /root/.local/bin/hermes /usr/local/bin/hermes || true"
    "  - test -f /root/.hermes/SOUL.md || cp /var/lib/hermes/SOUL.seed.md /root/.hermes/SOUL.md || true"
    "  - systemctl daemon-reload"
    "  - systemctl enable hermes-agent.service"
  ];
in
{
  options.homeServer.incusHermesAgent = {
    enable = lib.mkEnableOption "persistent Hermes Agent Incus VM (profile + backup timer)";

    vmName = lib.mkOption {
      type = lib.types.str;
      default = "hermes-agent";
      description = "Persistent Incus VM instance name";
    };

    profileName = lib.mkOption {
      type = lib.types.str;
      default = "hermes-agent";
      description = "Incus profile name providing cloud-init + limits";
    };

    limits = {
      cpu = lib.mkOption {
        type = lib.types.str;
        default = "2";
        description = "Incus limits.cpu for the Hermes profile";
      };

      memory = lib.mkOption {
        type = lib.types.str;
        default = "4GiB";
        description = "Incus limits.memory for the Hermes profile";
      };
    };

    backup = {
      enable = lib.mkEnableOption "daily restic backup of ~/.hermes to R2" // {
        default = true;
      };
      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = "systemd OnCalendar for hermes-backup.timer";
      };
    };

    bridge = {
      enable = lib.mkEnableOption "host MCP bridge from Hermes to byok-agent (incusbr0 only)";

      bindAddr = lib.mkOption {
        type = lib.types.str;
        default = "10.0.100.1";
        description = "Address to bind the coding-task bridge (incusbr0 host IP)";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8420;
        description = "TCP port for the coding-task bridge";
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
          "user.user-data" = cloudInitUserData;
          "cloud-init.user-data" = cloudInitUserData;
        };
      }
    ];

    systemd.services.hermes-agent-backup = lib.mkIf cfg.backup.enable {
      description = "Backup Hermes Agent ~/.hermes to R2";
      after = [ "network-online.target" ];
      requires = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
      };
      path = [
        pkgs.bash
        pkgs.curl
        pkgs.jq
        pkgs.python3
        pkgs.restic
        pkgs.gnutar
        pkgs.coreutils
      ];
      script = ''
        ${data.configDirectory}/tools/incus/hermes-backup.sh
      '';
    };

    systemd.timers.hermes-agent-backup = lib.mkIf cfg.backup.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backup.onCalendar;
        Persistent = true;
        Unit = "hermes-agent-backup.service";
      };
    };

    systemd.services.hermes-coding-bridge = lib.mkIf cfg.bridge.enable {
      description = "Hermes to byok-agent coding-task bridge";
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        EnvironmentFile = "-/run/agenix/hermes-bridge-secrets";
        Environment = [
          "BRIDGE_BIND_ADDR=${cfg.bridge.bindAddr}"
          "BRIDGE_PORT=${toString cfg.bridge.port}"
          "RUN_AGENT_TASK_SCRIPT=${data.configDirectory}/tools/incus/run-agent-task.sh"
        ];
        Restart = "on-failure";
        RestartSec = "10s";
      };
      path = [
        pkgs.bash
        pkgs.curl
        pkgs.jq
        pkgs.python3
        pkgs.coreutils
      ];
      script = ''
        exec ${pkgs.python3}/bin/python3 ${data.configDirectory}/tools/incus/coding-task-bridge/server.py
      '';
    };
  };
}
