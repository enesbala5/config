{
  config,
  pkgs,
  unstable,
  data,
  inputs,
  system,
  hostname,
  ...
}:
let
in
{

  # ------------------------------------------------------------------------------------------
  # Accounts
  # -> Don't forget to set a password with ‘passwd’.
  # ------------------------------------------------------------------------------------------

  users = {
    users = {
      root = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP2a8Wi7Cg+p5OBRW3YPxFDhJ3xFTdMvdwMI1GQX6I7M root@coolify"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP2a8Wi7Cg+p5OBRW3YPxFDhJ3xFTdMvdwMI1GQX6I7M"
        ];

        extraGroups = [
          "incus-admin"
        ];
      };

      guest = {
        isNormalUser = true;
        description = "Guest";
        extraGroups = [
          "networkmanager"
          "wheel"
          "docker"
          "video"
        ];
        shell = pkgs.zsh;
      };
    };

    groups.vboxusers.members = [ data.username ];
  };

  # ------------------------------------------------------------------------------------------
  # Virtualisation
  # ------------------------------------------------------------------------------------------

  virtualisation = {
    incus = {
      enable = true;
      ui.enable = true; # This installs the Web UI files

      preseed = {
        config = {
          "core.https_address" = "127.0.0.1:8443";
        };

        networks = [
          {
            config = {
              "ipv4.address" = "10.0.100.1/24";
              "ipv4.nat" = "true";
            };

            name = "incusbr0";
            type = "bridge";
          }
        ];

        profiles = [
          {
            devices = {
              eth0 = {
                name = "eth0";
                network = "incusbr0";
                type = "nic";
              };
              root = {
                path = "/";
                pool = "default";
                size = "35GiB";
                type = "disk";
              };
            };
            name = "default";
          }
        ];

        storage_pools = [
          {
            config = {
              source = "/var/lib/incus/storage-pools/default";
            };
            driver = "dir";
            name = "default";
          }
        ];
      };
    };
  };

  # ------------------------------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------------------------------

  networking = {
    # Necessary for Incus
    nftables = {
      enable = true;
      flushRuleset = false;
    };

    firewall = {
      allowedTCPPorts = [
        8000
        445
        8006
        18789
        9510
        9512
        11470
        12470
      ];

      allowedUDPPorts = [
        9511
        9512
        11470
        12470
      ];

      # Necessary for Incus
      trustedInterfaces = [ "incusbr0" ];
    };
  };

  # ------------------------------------------------------------------------------------------
  # Services
  # ------------------------------------------------------------------------------------------

  services = {
    openssh = {
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
      };
    };
  };

  systemd = {
    services = {
      deploy-merre = {
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

      db-backup-merre = {
        enable = true;
        description = "Backup Merre Database to Cloudflare R2";
        after = [
          "network-online.target"
          "docker.service"
        ];
        requires = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = data.username;
          Group = "users";
          WorkingDirectory = "${data.homeDirectory}/dev/merre/";
          EnvironmentFile = config.age.secrets.merre-database-backup-env.path;
        };
        script = ''
          #! ${pkgs.bash}/bin/bash
          set -euo pipefail

          notify_failure() {
            ${data.configDirectory}/tools/telegram/notify.sh \
              "❌ *Merre database backup failed on ${hostname}*
          $1" || true
          }

          BACKUP_FILE="merre-db.sql.gz"

          if ! ${pkgs.docker}/bin/docker compose \
            --env-file .env --env-file .env.prod \
            -f docker-compose.yaml -f docker-compose.prod.yaml \
            exec -T database pg_dumpall -U admin \
            | ${pkgs.gzip}/bin/gzip -9c > "$BACKUP_FILE"; then
            notify_failure "Failed to dump and compress PostgreSQL backup."
            exit 1
          fi

          BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
          echo "Dump complete ($BACKUP_SIZE), backing up with restic..."

          if ! ${pkgs.restic}/bin/restic backup \
            --tag merre \
            --tag automated \
            "$BACKUP_FILE"; then
            notify_failure "restic backup command returned non-zero."
            rm -f "$BACKUP_FILE"
            exit 1
          fi

          if ! ${pkgs.restic}/bin/restic forget \
            --prune \
            --keep-daily 7 \
            --keep-weekly 4 \
            --keep-monthly 3; then
            notify_failure "restic forget --prune command returned non-zero."
            rm -f "$BACKUP_FILE"
            exit 1
          fi

          SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --latest 1 --json \
            | ${pkgs.jq}/bin/jq -r '.[0].short_id')

          rm -f "$BACKUP_FILE"

          echo "Done. Snapshot: $SNAPSHOT"
        '';
      };

      db-backup-coverlttr = {
        enable = true;
        description = "Backup Coverlttr Database to Cloudflare R2";
        after = [
          "network-online.target"
          "docker.service"
        ];
        requires = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = data.username;
          Group = "users";
          WorkingDirectory = "${data.homeDirectory}/dev/coverlttr/";
          EnvironmentFile = config.age.secrets.coverlttr-database-backup-env.path;
        };
        script = ''
          #! ${pkgs.bash}/bin/bash
          set -euo pipefail

          notify_failure() {
            ${data.configDirectory}/tools/telegram/notify.sh \
              "❌ *Coverlttr database backup failed on ${hostname}*
          $1" || true
          }

          BACKUP_FILE="coverlttr-db.sql.gz"

          if ! ${pkgs.docker}/bin/docker compose \
            --env-file .env --env-file .env.prod \
            -f docker-compose.yaml -f docker-compose.prod.yaml \
            exec -T database pg_dumpall -U admin \
            | ${pkgs.gzip}/bin/gzip -9c > "$BACKUP_FILE"; then
            notify_failure "Failed to dump and compress PostgreSQL backup."
            exit 1
          fi

          BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
          echo "Dump complete ($BACKUP_SIZE), backing up with restic..."

          if ! ${pkgs.restic}/bin/restic backup \
            --tag coverlttr \
            --tag automated \
            "$BACKUP_FILE"; then
            notify_failure "restic backup command returned non-zero."
            rm -f "$BACKUP_FILE"
            exit 1
          fi

          if ! ${pkgs.restic}/bin/restic forget \
            --prune \
            --keep-daily 7 \
            --keep-weekly 4 \
            --keep-monthly 3; then
            notify_failure "restic forget --prune command returned non-zero."
            rm -f "$BACKUP_FILE"
            exit 1
          fi

          SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --latest 1 --json \
            | ${pkgs.jq}/bin/jq -r '.[0].short_id')

          rm -f "$BACKUP_FILE"

          echo "Done. Snapshot: $SNAPSHOT"
        '';
      };

      db-backup-audiobookshelf = {
        enable = true;
        description = "Backup Audiobookshelf Config & Metadata to Cloudflare R2";
        after = [
          "network-online.target"
          "docker.service"
        ];
        requires = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Group = "root";
          EnvironmentFile = config.age.secrets.audiobookshelf-database-backup-env.path;
        };
        script = ''
          #! ${pkgs.bash}/bin/bash
          set -euo pipefail

          notify_failure() {
            ${data.configDirectory}/tools/telegram/notify.sh \
              "❌ *Audiobookshelf backup failed on ${hostname}*
          $1" || true
          }

          DATE=$(date '+%Y-%m-%d_%H-%M')

          echo "Starting Audiobookshelf backup: $DATE"

          ABS_CONTAINER=$(${pkgs.docker}/bin/docker ps --format '{{.Names}}' | grep audiobookshelf | head -n1)

          if [ -z "$ABS_CONTAINER" ]; then
            notify_failure "Audiobookshelf container not found."
            exit 1
          fi

          echo "Found container: $ABS_CONTAINER"

          CONFIG_PATH=$(${pkgs.docker}/bin/docker inspect "$ABS_CONTAINER" \
            --format '{{ range .Mounts }}{{ if eq .Destination "/config" }}{{ .Source }}{{ end }}{{ end }}')
          METADATA_PATH=$(${pkgs.docker}/bin/docker inspect "$ABS_CONTAINER" \
            --format '{{ range .Mounts }}{{ if eq .Destination "/metadata" }}{{ .Source }}{{ end }}{{ end }}')

          echo "Config path: $CONFIG_PATH"
          echo "Metadata path: $METADATA_PATH"

          echo "Stopping Audiobookshelf container..."

          if ! ${pkgs.docker}/bin/docker stop "$ABS_CONTAINER"; then
            notify_failure "Failed to stop container $ABS_CONTAINER."
            exit 1
          fi

          if ! ${pkgs.restic}/bin/restic backup \
            --tag audiobookshelf \
            --tag automated \
            "$CONFIG_PATH" "$METADATA_PATH"; then
            ${pkgs.docker}/bin/docker start "$ABS_CONTAINER" || true
            notify_failure "restic backup command returned non-zero."
            exit 1
          fi

          if ! ${pkgs.restic}/bin/restic forget \
            --prune \
            --keep-daily 7 \
            --keep-weekly 4 \
            --keep-monthly 3; then
            ${pkgs.docker}/bin/docker start "$ABS_CONTAINER" || true
            notify_failure "restic forget --prune command returned non-zero."
            exit 1
          fi

          echo "Starting Audiobookshelf container..."

          if ! ${pkgs.docker}/bin/docker start "$ABS_CONTAINER"; then
            notify_failure "Backup completed, but failed to restart container $ABS_CONTAINER."
            exit 1
          fi

          SNAPSHOT=$(${pkgs.restic}/bin/restic snapshots --latest 1 --json \
            | ${pkgs.jq}/bin/jq -r '.[0].short_id')

          echo "Done. Snapshot: $SNAPSHOT"
        '';
      };

      restart-cloudflared = {
        enable = true;
        description = "Restart Cloudflared Docker container (auto-recovery)";
        after = [
          "network-online.target"
          "docker.service"
        ];
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
            ${data.configDirectory}/tools/telegram/notify.sh \
              "❌ *Cloudflared restart failed on ${hostname}*
          $1" || true
          }

          CF_CONTAINER=$(${pkgs.docker}/bin/docker ps --format '{{.Names}}' \
            | grep '^cloudflared-' | head -n1)

          if [ -z "$CF_CONTAINER" ]; then
            notify_failure "Could not locate a running container matching cloudflared-*."
            exit 1
          fi

          echo "Found Cloudflared container: $CF_CONTAINER"

          if ! ${pkgs.docker}/bin/docker restart "$CF_CONTAINER"; then
            notify_failure "docker restart $CF_CONTAINER returned non-zero."
            exit 1
          fi

          echo "Restarted $CF_CONTAINER successfully."
        '';
      };

      notify-server-boot = {
        enable = true;
        description = "Send Telegram notification when server boots";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        requires = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Group = "root";
          EnvironmentFile = config.age.secrets.notify-server-boot-service-env.path;
        };
        script = ''
          #! ${pkgs.bash}/bin/bash
          set -euo pipefail

          BOOT_TIME=$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S %Z')

          ${data.configDirectory}/tools/telegram/notify.sh \
            "🚀 *Home Server is online!*
          🖥️ Host: ${hostname}
          🕒 Boot time: $BOOT_TIME
          ✅ System reached multi-user target."
        '';
      };

      pm2 = {
        enable = true;
        description = "PM2 process manager";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        unitConfig = {
          Type = "simple";
        };
        environment = {
          PM2_HOME = "${data.homeDirectory}/.pm2"; # Stores process list and logs
        };
        serviceConfig = {
          User = data.username;
          ExecStart = "${pkgs.pm2}/bin/pm2 resurrect";
          ExecReload = "${pkgs.pm2}/bin/pm2 reload all";
          ExecStop = "${pkgs.pm2}/bin/pm2 kill";
          Restart = "always";
        };
      };

      coolify-prepare-files = {
        description = "Setup files for coolify";
        wantedBy = [ "coolify.service" ];
        wants = [ "data-coolify.mount" ];
        script = ''
          #! ${pkgs.bash}/bin/bash
          NAMES='source ssh applications databases backups services proxy webhooks-during-maintenance ssh/keys ssh/mux proxy/dynamic'
          for NAME in $NAMES
          do
            FOLDER_PATH="/data/coolify/$NAME"
            if [ ! -d "$FOLDER_PATH" ]; then
              mkdir -p "$FOLDER_PATH"
            fi
          done

          cp -f "${data.configDirectory}/tools/coolify/docker-compose.yml" /data/coolify/source/docker-compose.yml
          cp -f "${data.configDirectory}/tools/coolify/docker-compose.prod.yml" /data/coolify/source/docker-compose.prod.yml
          cp -f "${data.configDirectory}/tools/coolify/upgrade.sh" /data/coolify/source/upgrade.sh
          cp -f "${config.age.secrets.coolify-env.path}" /data/coolify/source/.env

          # Generate SSH key if not ready -> IF IT BREAKS (ISSUE IS VERY LIKELY HERE - GO RUN IT MANUALLY)
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

      coolify = {
        script = ''
          "${pkgs.docker}/bin/docker" compose --env-file /data/coolify/source/.env -f /data/coolify/source/docker-compose.yml -f /data/coolify/source/docker-compose.prod.yml up -d
        '';

        after = [
          "docker.service"
          "docker.socket"
        ];

        wantedBy = [ "multi-user.target" ];
      };
    };

    timers = {
      deploy-merre = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5m";
          OnUnitActiveSec = "5m";
          Unit = "deploy-merre.service";
        };
      };

      db-backup-merre = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "02:00";
          Persistent = true;
          Unit = "db-backup-merre.service";
        };
      };

      db-backup-coverlttr = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "02:30";
          Persistent = true;
          Unit = "db-backup-coverlttr.service";
        };
      };

      db-backup-audiobookshelf = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "03:00";
          Persistent = true;
          Unit = "db-backup-audiobookshelf.service";
        };
      };

      restart-cloudflared = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "04:00";
          Persistent = true;
          Unit = "restart-cloudflared.service";
        };
      };

      restart-onlyoffice-nginx = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30m";
          OnUnitActiveSec = "30m";
          Unit = "restart-onlyoffice-nginx.service";
        };
      };
    };

    # Stop Gnome from suspending, copied from https://discourse.nixos.org/t/stop-pc-from-sleep/5757/2
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };

  # ------------------------------------------------------------------------------------------
  # Kernel & Bootloader
  # ------------------------------------------------------------------------------------------

  boot = {
    loader = {
      # efi.canTouchEfiVariables = true;

      grub = {
        enable = false;
      };
    };
  };

  # Memory Management
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024; # 8 GB
    }
  ];

  # Hard Drive Idle - Uncomment after adding HDD to the system
  # ---
  # systemd.services.hd-idle = {
  #   description = "HD spin down daemon, spins down disks after 15 minutes of inactivity";
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     Type = "simple";
  #     ExecStart = "${pkgs.hd-idle}/bin/hd-idle -i 900";
  #   };
  # };

  # ------------------------------------------------------------------------------------------
  # Security
  # ------------------------------------------------------------------------------------------

  security = { };

  # ------------------------------------------------------------------------------------------
  # Hardware
  # ------------------------------------------------------------------------------------------

  hardware = {
    graphics = {
      enable = true;

      # package = unstable.mesa.drivers;
      # driSupport32Bit = true;
      # package32 = unstable.pkgsi686Linux.mesa.drivers;
    };
  };

  # ------------------------------------------------------------------------------------------
  # Programs & Generic Installs
  # ------------------------------------------------------------------------------------------

  # List packages installed in system profile. To search, run: `nix search wget`
  environment.systemPackages = with pkgs; [
    pm2
    restic
  ];

  programs = {
    steam = {
      enable = false;

      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    };
  };

  # ------------------------------------------------------------------------------------------
  # Home Manager
  # ------------------------------------------------------------------------------------------

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
        ../../modules/home/default.nix
      ];
    };
  };
}
