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
  imports = [
    ./modules/garage
    ./modules/disks/smartd.nix
    ./modules/power/ups.nix
    ./modules/backups
  ];

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
      allowPing = true;

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

    samba = {
      # The full package is needed to register mDNS records (for discoverability), see discussion in
      # https://gist.github.com/vy-let/a030c1079f09ecae4135aebf1e121ea6
      package = pkgs.samba4Full;
      usershares.enable = true;
      enable = true;
      openFirewall = true;

      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "home-server";
          "netbios name" = "home-server";

          "security" = "user";
          #"use sendfile" = "yes";
          #"max protocol" = "smb2";
          # note: localhost is the ipv6 localhost ::1

          "hosts allow" = "192.168.0. 127.0.0.1 localhost";
          "hosts deny" = "0.0.0.0/0";
          "guest account" = "nobody";
          "map to guest" = "bad user";
        };

        # "public" = {
        #   "path" = "/mnt/hdd/";
        #   "browseable" = "yes";
        #   "read only" = "no";
        #   "guest ok" = "yes";
        #   "create mask" = "0644";
        #   "directory mask" = "0755";
        #   "force user" = "username";
        #   "force group" = "groupname";
        # };
        "private" = {
          "path" = "/mnt/hdd/nas";
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = data.username;
          "force group" = "users"; # or whatever primary group user 'e' uses
          "valid users" = data.username;
        };
      };
    };

    # To be discoverable with windows
    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };

    avahi = {
      publish.enable = true;
      publish.userServices = true;
      
      # ^^ Needed to allow samba to automatically register mDNS records (without the need for an `extraServiceFile`
      nssmdns4 = true;
      # ^^ Not one hundred percent sure if this is needed- if it aint broke, don't fix it
      enable = true;
      openFirewall = true;
    };

    tailscale.enable = true;

    fail2ban.enable = true;
  };

  system.activationScripts = {
    # The "init_smbpasswd" script name is arbitrary, but a useful label for tracking
    # failed scripts in the build output. An absolute path to smbpasswd is necessary
    # as it is not in $PATH in the activation script's environment. The password
    # is repeated twice with newline characters as smbpasswd requires a password
    # confirmation even in non-interactive mode where input is piped in through stdin.
    init_smbpasswd = {
      deps = [
        "users"
        "agenix"
      ];
      text = ''
        SECRET_PATH="${config.age.secrets.e-auth.path}"
        if [ -f "$SECRET_PATH" ] && id "${data.username}" &>/dev/null; then
          /run/current-system/sw/bin/printf "$(/run/current-system/sw/bin/cat "$SECRET_PATH")\n$(/run/current-system/sw/bin/cat "$SECRET_PATH")\n" | /run/current-system/sw/bin/smbpasswd -sa ${data.username}
        fi
      '';
    };
  };

  systemd = {
    services = {
      # Remote/Cloudflare SSH: do not kill sshd mid-switch. Activation restarts
      # sshd by default, which drops the tunnel and can abort switch before
      # docker.socket starts. Apply sshd changes on reboot or: systemctl restart sshd
      sshd = {
        restartIfChanged = false;
        stopIfChanged = false;
      };

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
        wants = [ "network-online.target" ];
        # Don't re-run on every nixos-rebuild switch — only on boot / first start.
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

          # Telegram outages must not fail nixos-rebuild switch / boot activation.
          ${data.configDirectory}/tools/telegram/notify.sh \
            "🚀 *Home Server is online!*
          🖥️ Host: ${hostname}
          🕒 Boot time: $BOOT_TIME
          ✅ System reached multi-user target." \
            || echo "Telegram boot notification failed (non-fatal)" >&2
        '';
      };

      pm2 = {
        enable = true;
        description = "PM2 process manager";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        unitConfig = {
          Type = "forking";
        };
        environment = {
          PM2_HOME = "${data.homeDirectory}/.pm2";
        };
        serviceConfig = {
          User = data.username;
          PIDFile = "${data.homeDirectory}/.pm2/pm2.pid";
          ExecStart = "${pkgs.pm2}/bin/pm2 resurrect";
          ExecReload = "${pkgs.pm2}/bin/pm2 reload all";
          ExecStop = "${pkgs.pm2}/bin/pm2 kill";
          Restart = "on-failure";
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

      restart-cloudflared = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "04:00";
          Persistent = true;
          Unit = "restart-cloudflared.service";
        };
      };

      # restart-onlyoffice-nginx = {
      #   wantedBy = [ "timers.target" ];
      #   timerConfig = {
      #     OnBootSec = "30m";
      #     OnUnitActiveSec = "30m";
      #     Unit = "restart-onlyoffice-nginx.service";
      #   };
      # };
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
      grub = {
        enable = true;
        # BIOS/MBR (single msdos partition, no ESP). by-id pins this to the
        # system NVMe so GRUB is not installed to the data HDD.
        device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_500GB_S4EVNX1W425280F";
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
        ./home/default.nix
      ];
    };
  };
}
