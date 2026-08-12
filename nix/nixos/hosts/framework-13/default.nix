{
  config,
  pkgs,
  lib,
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
    # Input-server capability wrapper (clipboard paste, snippets, etc.)
    inputs.vicinae.nixosModules.default
  ];

  # ------------------------------------------------------------------------------------------
  # Accounts
  # -> Don't forget to set a password with 'passwd'.
  # ------------------------------------------------------------------------------------------

  users = {
    users.${data.username}.extraGroups = [
      "adbusers" # ADB Support
    ];
  };

  # Seed a writable rclone.conf for gdrive bisync (OAuth token refresh).
  # Overwritten on every activation (rebuild/boot) from the agenix secret.
  # Other remotes (r2, b2, …) should keep using config.age.secrets.rclone-conf.path.
  system.activationScripts.rcloneGdriveConfig = {
    deps = [ "agenix" ];
    text = ''
      install -d -m 700 -o ${data.username} -g users ${data.homeDirectory}/.config/rclone
      install -m 600 -o ${data.username} -g users ${config.age.secrets.rclone-conf.path} ${data.rcloneGdriveConfigPath}
    '';
  };

  # ------------------------------------------------------------------------------------------
  # File System
  # ------------------------------------------------------------------------------------------

  # Mounting Windows File System

  # fileSystems."/mnt/Windows" = {
  #  device = "/dev/nvme0n1p4";
  #  fsType = "ntfs-3g";
  # options =
  #   [ # If you don't have this options attribute, it'll default to "defaults"
  #     # boot options for fstab. Search up fstab mount options you can use
  #     "users" # Allows any user to mount and unmount
  #     "nofail" # Prevent system from failing if this drive doesn't mount
  #   ];
  # };

  # ------------------------------------------------------------------------------------------
  # General Settings
  # ------------------------------------------------------------------------------------------

  # Environment Configuration
  environment = {
    sessionVariables = {
      HOME = data.homeDirectory;

      PATH = "/run/current-system/sw/bin:/run/wrappers/bin";
    };
  };

  powerManagement = {
    enable = true;

    # powertop.enable = true;
  };

  console = {
    font = "ter-132n";
    packages = with pkgs; [ terminus_font ];
    keyMap = "us";
  };

  # ------------------------------------------------------------------------------------------
  # Virtualisation
  # ------------------------------------------------------------------------------------------

  virtualisation.virtualbox.host = {
    enable = true;
    enableKvm = true;

    addNetworkInterface = false;
  };

  # ------------------------------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------------------------------

  networking = {
    firewall = {
      allowedTCPPorts = [
        9510
        9512
        53317 # LocalSend
      ];

      allowedUDPPorts = [
        9511
        9512
        53317 # LocalSend
      ];

      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];

      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
    };

    # Bind domain names to IP addresses.
    extraHosts = ''
        127.0.0.1 brennero-bim.test
        192.168.41.4 gitlab.sedetn01.a22
        127.0.0.1 onlyoffice.test

      	192.168.10.116 cantieri.autobrennero.it
        192.168.10.125 cantieridocs.autobrennero.it

        127.0.0.1 landing.in2me.test
        127.0.0.1 in2me.test
    '';
  };

  # ------------------------------------------------------------------------------------------
  # Services
  # ------------------------------------------------------------------------------------------

  services = {
    # Ensure EasyEffects is not selected automatically as the default audio sink
    pipewire.wireplumber.extraConfig = {
      "52-hide-easyeffects-sink" = {
        "monitor.pipewire.rules" = [
          {
            matches = [ { "node.name" = "~easyeffects_sink.*"; } ];
            actions = {
              update-props = {
                "priority.session" = -1;
              };
            };
          }
        ];
      };
      "52-disable-ryzen-mic" = {
        "monitor.alsa.rules" = [
          {
            matches = [ { "node.name" = "alsa_input.pci-0000_c1_00.6.pro-input-0"; } ];
            actions = {
              update-props = {
                "node.disabled" = true;
              };
            };
          }
        ];
      };
    };

    teamviewer.enable = true;

    tailscale.enable = true;

    upower.enable = true;

    ratbagd = {
      enable = true;
    };

    # Framework 13 - BIOS Update Toggle & Fetching correct version in order to downgrade fingerprint sensor firmware
    fwupd = {
      # Automatic Updates
      enable = true;

      # We need fwupd 1.9.7 to downgrade the fingerprint sensor firmware
      package =
        (import (builtins.fetchTarball {
          url = "https://github.com/NixOS/nixpkgs/archive/bb2009ca185d97813e75736c2b8d1d8bb81bde05.tar.gz";
          sha256 = "sha256:003qcrsq5g5lggfrpq31gcvj82lb065xvr7bpfa8ddsw8x4dnysk";
        }) { inherit (pkgs) system; }).fwupd;
    };

    # Fingerprint
    fprintd = {
      enable = true;
    };

    # udev
    udev = {
      enable = true;
      # Active Rules: Brightness Control
      packages = with pkgs; [ brillo ];
    };

    power-profiles-daemon.enable = true;

    # Enable CUPS to print documents.
    printing.enable = true;

    # Enable Flatpak Support
    flatpak = {
      enable = true;
    };

    # Power management.
    logind = {
      settings.Login.HandlePowerKey = "suspend"; # Suspend on power button press
      settings.Login.HandlePowerKeyLongPress = "poweroff"; # Power off on long press
    };

    acpid = {
      enable = true;
      lidEventCommands = ''
        export PATH=$PATH:/run/current-system/sw/bin

        lid_state=$(cat /proc/acpi/button/lid/LID0/state | awk '{print $NF}')

        if [ $lid_state = "closed" ]; then
          # Set brightness to zero
          brillo -e -u 0 -S 10

        else
          # Reset the brightness
          brillo -e -u 0 -S 50
        fi
      '';

      powerEventCommands = ''
        systemctl suspend
      '';
    };
  };

  systemd = {
    services = {
      NetworkManager-wait-online.enable = false;

      power-profile-handler = {
        description = "Power Profile Handler - Monitor & apply changes (system)";
        wantedBy = [ "multi-user.target" ];

        after = [
          "network.target"
          "power-profiles-daemon.service"
          "dbus.service"
        ];

        serviceConfig = {
          Type = "simple";
          ExecStartPre = "${pkgs.bash}/bin/bash -c '${pkgs.power-profiles-daemon}/bin/powerprofilesctl configure-battery-aware --disable || true'";
          ExecStart = "${pkgs.bash}/bin/bash ${data.configDirectory}/scripts/hosts/framework-13/power-profiles/power-profile-monitor.sh";
          Restart = "on-failure";
          RestartSec = 5;
          Environment = [
            "PATH=/run/current-system/sw/bin:/run/wrappers/bin"
            "TARGET_USER=${data.username}"
          ];
        };
      };

      # display-manager.environment.XDG_CURRENT_DESKTOP = "X-NIXOS-SYSTEMD-AWARE";

      rclone = {
        enable = true;
        description = "Service that connects to Google Drive";

        # No wantedBy: started only by rclone.timer / rclone.path (or manually).
        # Power-profile-handler starts those units outside power-saver mode.
        after = [ "network-online.target" ];
        documentation = [ "man:rclone(1)" ];
        requires = [ "network-online.target" ];

        startLimitIntervalSec = 60;
        startLimitBurst = 1;

        # Service configuration
        serviceConfig = {
          Type = "simple";
          ExecStartPre = "/run/current-system/sw/bin/mkdir -p ${data.googleDriveLocalDir}"; # Create folder if it doesn't exist
          ExecStart = "${data.configDirectory}/tools/rclone/scripts/rclone-bisync.sh";
          Restart = "on-failure";
          RestartSec = "15s";
          User = data.username;
          Group = "users";
          Environment = [
            "HOME=${data.homeDirectory}"
            "RCLONE_CONFIG=${data.rcloneGdriveConfigPath}"
            "RCLONE_REMOTE_NAME=${data.googleDriveRemoteName}"
            "RCLONE_LOCAL_DIR=${data.googleDriveLocalDir}"
            "PATH=/run/current-system/sw/bin:/run/wrappers/bin"
            "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${toString data.uid}/bus"
          ];
        };
      };
    };

    user.services.amd-audio-reinit = {
      description = "Re-initialize AMD Ryzen HD audio profile on boot";
      wantedBy = [ "default.target" ];
      after = [ "wireplumber.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "amd-audio-reinit" ''
          sleep 10
          ${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_c1_00.6 output:analog-stereo
          sleep 1
          ${pkgs.pulseaudio}/bin/pactl set-card-profile alsa_card.pci-0000_c1_00.6 pro-audio
          sleep 1
          ${pkgs.pulseaudio}/bin/pactl set-default-sink alsa_output.pci-0000_c1_00.6.pro-output-0
        '';
      };
    };

    # CRON Jobs Equivalents
    timers = {
      rclone = {
        # Started by power-profile-handler outside power-saver (not on boot).
        wantedBy = [ ];

        timerConfig = {
          Unit = "rclone.service";
          OnCalendar = "*:0/30";
          Persistent = true;
        };
      };
      systemd-tmpfiles-clean = {
        timerConfig = {
          OnBootSec = "15min"; # Delay after boot instead of during
        };
      };
    };

    # File Watcher
    paths = {
      rclone = {
        # Started by power-profile-handler outside power-saver (not on boot).
        wantedBy = [ ];

        pathConfig = {
          PathChanged = data.googleDriveLocalDir;
          Unit = "rclone.service";
        };
      };
    };
  };

  # ------------------------------------------------------------------------------------------
  # Kernel & Bootloader
  # ------------------------------------------------------------------------------------------

  boot = {
    kernelModules = [ "acpi_call" ];
    extraModulePackages = with config.boot.kernelPackages; [ acpi_call ];

    consoleLogLevel = 0;
    plymouth.enable = true;
    initrd.verbose = false;
    # zswap compressor/zpool must be available before swap is activated
    initrd.kernelModules = [
      "zstd"
      "zsmalloc"
    ];

    kernelParams = [
      "quiet"
      "splash"

      "udev.log_level=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "boot.shell_on_fail"

      # Hibernation
      "resume_offset=8589934592"
      # Other
      "acpi_osi=Linux"
      "acpi_backlight=native"
      # Battery optimization
      "mem_sleep_default=deep"
      "pcie_aspm.policy=powersave"
      "amd_pstate=active"
      "amdgpu.dpm=1"
      "amdgpu.ppfeaturemask=0xffffffff"

      # zswap: compressed RAM cache in front of the swap partition
      # (boot.zswap.* lands in nixpkgs after 25.11; these are the module defaults)
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.zpool=zsmalloc"
      "zswap.max_pool_percent=25"
      "zswap.accept_threshold_percent=90"
      "zswap.shrinker_enabled=1"
    ];

    loader = {
      efi.canTouchEfiVariables = true;

      grub = {
        enable = true;
        useOSProber = true;
        efiSupport = true;
        device = "nodev";
        splashImage = null;
        backgroundColor = "#000000";
        theme = pkgs.stdenv.mkDerivation {
          pname = "minimal-grub-theme";
          version = "0.3.0";

          src = pkgs.fetchFromGitHub {
            owner = "tomdewildt";
            repo = "minimal-grub-theme";
            rev = "v0.3.0";
            hash = "sha256-CegLznlW+UJZbVe+WG/S8tREFdw0aq3flGvJeDrLWK0=";
          };

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/

            cp -r minimal/icons minimal/theme.txt minimal/*.png $out/

            runHook postInstall
          '';
        };
      };

      systemd-boot.consoleMode = "auto";
    };
  };

  # Memory Management
  # Swap partition: hardware-configuration.nix (by-uuid).
  # zswap (boot.kernelParams above) compresses pages in RAM, then writebacks to that partition.

  # ------------------------------------------------------------------------------------------
  # Security
  # ------------------------------------------------------------------------------------------

  security = {
    # pki = {
    #   certificateFiles = [
    #     ./certificates/incus/incus.enesbala.com.crt
    #   ];
    # };
  };

  # ------------------------------------------------------------------------------------------
  # Hardware
  # ------------------------------------------------------------------------------------------

  hardware = {
    graphics.enable = true;
  };

  # ------------------------------------------------------------------------------------------
  # Programs & Generic Installs
  # ------------------------------------------------------------------------------------------

  # List packages installed in system profile. To search, run: `nix search wget`
  environment.systemPackages =
    (with pkgs; [
      fprintd
      teamviewer
      powertop
      iw
      # Handle Windows Filesystem NTFS
      killall
      cloc
      acpi
      acpid
      acpilight
      evtest
      piper
      qemu
      quickemu
      converseen
      dnsmasq
      phodav
      devcontainer
      restic

      # Native host for Plasma Browser Integration (extension still installed in-browser)
      kdePackages.plasma-browser-integration
    ])
    ++ (with unstable; [
    ])
    ++ [
      inputs.aw-watcher-window-hyprland.defaultPackage.${system}
    ];

  programs = {
    virt-manager.enable = true;

    adb.enable = true;

    dconf.enable = true;

    kdeconnect.enable = true;
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

  # ------------------------------------------------------------------------------------------
  # Specialisations
  # ------------------------------------------------------------------------------------------

  specialisation = {
    light.configuration = {
      home-manager.users.${data.username} = {
        stylix.polarity = lib.mkForce "light";
        stylix.base16Scheme = lib.mkForce data.schemes.light;
      };
    };
    dark.configuration = {
      home-manager.users.${data.username} = {
        stylix.polarity = lib.mkForce "dark";
        stylix.base16Scheme = lib.mkForce data.schemes.dark;
      };
    };
  };
}
