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
    ./modules/incus-ai-agent
    ./modules/incus-hermes-agent
    ./modules/openhands-ui
  ];

  # Flip on after `manage-secret incus-ai-agent-secrets.age` and first apply.
  homeServer.incusAiAgent.enable = true;

  # Flip on after `manage-secret hermes-agent-secrets.age`.
  homeServer.incusHermesAgent.enable = false;
  # homeServer.incusHermesAgent.bridge.enable = true; # after hermes-bridge-secrets.age
  homeServer.openHandsUi.enable = false;

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
      ui.enable = true;

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

  networking = {
    nftables = {
      enable = true;
      flushRuleset = false;
    };

    firewall = {
      allowPing = true;
      allowedTCPPorts = [ 8000 445 8006 18789 9510 9512 11470 12470 ];
      allowedUDPPorts = [ 9511 9512 11470 12470 ];
      trustedInterfaces = [ "incusbr0" ];
    };
  };

  services = {
    openssh.settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };

    samba = {
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
          "hosts allow" = "192.168.0. 127.0.0.1 localhost";
          "hosts deny" = "0.0.0.0/0";
          "guest account" = "nobody";
          "map to guest" = "bad user";
        };
        "private" = {
          "path" = "/mnt/hdd/nas";
          "browseable" = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = data.username;
          "force group" = "users";
          "valid users" = data.username;
        };
      };
    };

    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };

    avahi = {
      publish.enable = true;
      publish.userServices = true;
      nssmdns4 = true;
      enable = true;
      openFirewall = true;
    };

    tailscale = {
      enable = true;
      package = unstable.tailscale;
    };

    fail2ban.enable = true;
  };

  system.activationScripts.init_smbpasswd = {
    deps = [ "users" "agenix" ];
    text = ''
      SECRET_PATH="${config.age.secrets.e-auth.path}"
      if [ -f "$SECRET_PATH" ] && id "${data.username}" &>/dev/null; then
        /run/current-system/sw/bin/printf "$(/run/current-system/sw/bin/cat "$SECRET_PATH")\n$(/run/current-system/sw/bin/cat "$SECRET_PATH")\n" | /run/current-system/sw/bin/smbpasswd -sa ${data.username}
      fi
    '';
  };

  systemd = {
    services = {
      sshd = {
        restartIfChanged = false;
        stopIfChanged = false;
      };
    };
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };
}
