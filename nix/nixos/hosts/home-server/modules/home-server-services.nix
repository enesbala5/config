{
  config,
  pkgs,
  data,
  inputs,
  system,
  hostname,
  unstable,
  ...
}:
{
  system.activationScripts.init_smbpasswd = {
    deps = [ "users" "agenix" ];
    text = ''
      SECRET_PATH="${config.age.secrets.e-auth.path}"
      if [ -f "$SECRET_PATH" ] && id "${data.username}" &>/dev/null; then
        /run/current-system/sw/bin/printf "$(/run/current-system/sw/bin/cat "$SECRET_PATH")\n$(/run/current-system/sw/bin/cat "$SECRET_PATH")\n" | /run/current-system/sw/bin/smbpasswd -sa ${data.username}
      fi
    '';
  };

  systemd.services.sshd = {
    restartIfChanged = false;
    stopIfChanged = false;
  };

  systemd.services.deploy-merre = {
    enable = true;
    description = "Deploy Merre";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      WorkingDirectory = "${data.homeDirectory}/dev/merre/misc/bin";
      ExecStart = "${data.homeDirectory}/dev/merre/misc/bin/deploy.sh prod up -d";
      Restart = "on-failure";
      RestartSec = "15s";
      User = data.username;
      Group = "users";
      Environment = [
        "HOME=${data.homeDirectory}"
        "PATH=/run/current-system/sw/bin:/run/wrappers/bin"
      ];
    };
  };

  systemd.services.restart-cloudflared = {
    enable = true;
    description = "Restart Cloudflared Docker container (auto-recovery)";
    after = [ "network-online.target" "docker.service" ];
    requires = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      EnvironmentFile = config.age.secrets.restart-cloudflared-service-env.path;
      Restart = "on-failure";
      RestartSec = "15s";
    };
    script = ''
      #! ${pkgs.bash}/bin/bash
      set -uo pipefail
      notify_failure() {
        ${data.configDirectory}/tools/telegram/notify.sh "Cloudflared restart failed on ${hostname}: $1" || true
      }
      CF_CONTAINER=$(${pkgs.docker}/bin/docker ps --format '{{.Names}}' | grep '^cloudflared-' | head -n1)
      if [ -z "$CF_CONTAINER" ]; then
        notify_failure "Could not locate a running container matching cloudflared-*."
        exit 1
      fi
      if ! ${pkgs.docker}/bin/docker restart "$CF_CONTAINER"; then
        notify_failure "docker restart $CF_CONTAINER returned non-zero."
        exit 1
      fi
    '';
  };

  systemd.services.notify-server-boot = {
    enable = true;
    description = "Send Telegram notification when server boots";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    restartIfChanged = false;
    stopIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      Group = "root";
      EnvironmentFile = config.age.secrets.notify-server-boot-service-env.path;
    };
    script = ''
      #! ${pkgs.bash}/bin/bash
      set -euo pipefail
      BOOT_TIME=$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S %Z')
      ${data.configDirectory}/tools/telegram/notify.sh \
        "Home Server is online. Host: ${hostname}. Boot time: $BOOT_TIME" \
        || echo "Telegram boot notification failed (non-fatal)" >&2
    '';
  };

  systemd.services.pm2 = {
    enable = true;
    description = "PM2 process manager";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    unitConfig.Type = "forking";
    environment.PM2_HOME = "${data.homeDirectory}/.pm2";
    serviceConfig = {
      User = data.username;
      PIDFile = "${data.homeDirectory}/.pm2/pm2.pid";
      ExecStart = "${pkgs.pm2}/bin/pm2 resurrect";
      ExecReload = "${pkgs.pm2}/bin/pm2 reload all";
      ExecStop = "${pkgs.pm2}/bin/pm2 kill";
      Restart = "on-failure";
    };
  };

  systemd.services.coolify-prepare-files = {
    description = "Setup files for coolify";
    wantedBy = [ "coolify.service" ];
    wants = [ "data-coolify.mount" ];
    script = ''
      #! ${pkgs.bash}/bin/bash
      NAMES='source ssh applications databases backups services proxy webhooks-during-maintenance ssh/keys ssh/mux proxy/dynamic'
      for NAME in $NAMES; do
        mkdir -p "/data/coolify/$NAME"
      done
      cp -f "${data.configDirectory}/tools/coolify/docker-compose.yml" /data/coolify/source/docker-compose.yml
      cp -f "${data.configDirectory}/tools/coolify/docker-compose.prod.yml" /data/coolify/source/docker-compose.prod.yml
      cp -f "${data.configDirectory}/tools/coolify/upgrade.sh" /data/coolify/source/upgrade.sh
      cp -f "${config.age.secrets.coolify-env.path}" /data/coolify/source/.env
      if [ ! -f "/data/coolify/ssh/keys/id.root@host.docker.internal" ]; then
        "${pkgs.openssh}/bin/ssh-keygen" -f /data/coolify/ssh/keys/id.root@host.docker.internal -t ed25519 -N "" -C root@coolify
        cat /data/coolify/ssh/keys/id.root@host.docker.internal.pub >> "/root/.ssh/authorized_keys"
        chmod 600 ~/.ssh/authorized_keys
      fi
      chown -R 9999:root /data/coolify
      chmod -R 700 /data/coolify
      "${pkgs.docker}/bin/docker" network inspect coolify >/dev/null 2>&1 || \
      "${pkgs.docker}/bin/docker" network create --attachable coolify
    '';
  };

  systemd.services.coolify = {
    script = ''
      "${pkgs.docker}/bin/docker" compose --env-file /data/coolify/source/.env -f /data/coolify/source/docker-compose.yml -f /data/coolify/source/docker-compose.prod.yml up -d
    '';
    after = [ "docker.service" "docker.socket" ];
    wantedBy = [ "multi-user.target" ];
  };

  systemd.timers.deploy-merre = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Unit = "deploy-merre.service";
    };
  };

  systemd.timers.restart-cloudflared = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
      Unit = "restart-cloudflared.service";
    };
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_500GB_S4EVNX1W425280F";
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024;
    }
  ];

  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs; [ pm2 restic ];

  programs.steam = {
    enable = false;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = false;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs;
      inherit system;
      inherit data;
      inherit unstable;
    };
    users.${data.username} = {
      imports = [
        ../../../modules/home/default.nix
        ../home/default.nix
      ];
    };
  };
}
