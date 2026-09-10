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

  userDataPath = "/etc/incus-profiles/${cfg.profileName}/user-data";
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
        incus profile set "$profile" cloud-init.user-data - < ${lib.escapeShellArg userDataPath}
        incus profile set "$profile" user.user-data - < ${lib.escapeShellArg userDataPath}
      '';
    };
  };
}
