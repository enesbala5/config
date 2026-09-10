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

    Coding work goes over HTTP to the OpenHands VM:
    POST http://byok-agent.incus:8090/tasks
    { "prompt": "...", "repo": "https://github.com/org/repo.git" }

    This VM holds memory, skills, Telegram, and scheduling.
    Never paste tokens into chat. Never write secrets into ~/.hermes memory.
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

    bridge = {
      enable = lib.mkEnableOption "optional host HTTP proxy from Hermes to OpenHands on byok-agent";

      bindAddr = lib.mkOption {
        type = lib.types.str;
        default = "10.0.100.1";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8420;
      };

      openHandsUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://byok-agent.incus:8090";
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

    systemd.services.hermes-coding-bridge = lib.mkIf cfg.bridge.enable {
      description = "Hermes HTTP proxy to OpenHands on byok-agent";
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
          "OPENHANDS_URL=${cfg.bridge.openHandsUrl}"
        ];
        Restart = "on-failure";
        RestartSec = "10s";
      };
      path = [
        pkgs.curl
        pkgs.python3
      ];
      script = ''
        exec ${pkgs.python3}/bin/python3 ${data.configDirectory}/tools/incus/coding-task-bridge/server.py
      '';
    };
  };
}
