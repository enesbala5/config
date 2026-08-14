{
  inputs,
  system,
  config,
  pkgs,
  unstable,
  lib,
  data,
  hostname,
  ...
}:
let
  hyprlandPackages = inputs.hyprland.packages.${system};
in
{
  # ------------------------------------------------------------------------------------------
  # NixOS / System
  # ------------------------------------------------------------------------------------------

  age.secrets =
    let
      secrets = import ../../secrets/secrets.nix;
    in
    lib.mapAttrs' (
      name: attrs:
      lib.nameValuePair (lib.removeSuffix ".age" name) {
        file = ../../secrets/${name};
        owner = attrs.owner or "root";
        group = attrs.group or "root";
        mode = attrs.mode or "0400";
      }
    ) secrets;

  nix = {
    package = unstable.nixVersions.latest;

    extraOptions = ''
      experimental-features = nix-command flakes
    '';

    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    settings.extra-substituters = [
      "https://vicinae.cachix.org"
      "https://zed.cachix.org"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
    ];

    settings.extra-trusted-public-keys = [
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];

    # Garbage Collections
    gc = {
      automatic = true;
      randomizedDelaySec = "14m";
      options = "--delete-older-than 10d";
    };
  };

  # ------------------------------------------------------------------------------------------
  # Accounts
  # -> Don't forget to set a password with 'passwd'.
  # ------------------------------------------------------------------------------------------

  users = {
    users = {
      ${data.username} = {
        isNormalUser = true;
        uid = data.uid;
        description = data.fullName;
        shell = pkgs.zsh;
        hashedPasswordFile = config.age.secrets.e-auth.path;

        extraGroups = [
          "networkmanager"
          "wheel"
          "docker"
          "video"
          "samba"
        ];
      };
    };

    groups = {
      libvirtd.members = [ data.username ];
      kvm.members = [ data.username ];
    };
  };

  # ------------------------------------------------------------------------------------------
  # General Settings
  # ------------------------------------------------------------------------------------------

  virtualisation = {
    docker.enable = true;

    libvirtd.enable = true;

    # Enable USB redirection
    spiceUSBRedirection.enable = true;
  };

  # Environment Configuration
  environment.sessionVariables = {
    # Hint electron apps to use wayland
    NIXOS_OZONE_WL = "1";

    # Qt Wayland platform for xdg-desktop-portal-kde and other Qt apps
    QT_QPA_PLATFORM = "wayland;xcb";

    # If cursor becomes invisible
    WLR_NO_HARDWARE_CURSORS = "1";

    # Allow insecure packages
    NIXPKGS_ALLOW_INSECURE = 1;

    HOME = data.homeDirectory;

    # Rclone config (shared so both framework and home-server can use it)
    RCLONE_CONFIG = config.age.secrets.rclone-conf.path;

    PATH = "/run/current-system/sw/bin:/run/wrappers/bin";

    # Other
    # ---
    USER_FULL_NAME = data.fullName;
    USER_EMAIL = data.email;
  };

  # System Settings
  # ---------

  # Set your time zone.
  time.timeZone = "Europe/Tirane";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "sq_AL.UTF-8";
    LC_IDENTIFICATION = "sq_AL.UTF-8";
    LC_MEASUREMENT = "sq_AL.UTF-8";
    LC_MONETARY = "sq_AL.UTF-8";
    LC_NAME = "sq_AL.UTF-8";
    LC_NUMERIC = "sq_AL.UTF-8";
    LC_PAPER = "sq_AL.UTF-8";
    LC_TELEPHONE = "sq_AL.UTF-8";
    LC_TIME = "sq_AL.UTF-8";
  };

  # ------------------------------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------------------------------

  networking = {
    hostName = hostname; # Define your hostname.

    networkmanager = {
      enable = true;
      plugins = with pkgs; [
        networkmanager-fortisslvpn
        networkmanager-l2tp
        networkmanager-openvpn
        networkmanager-openconnect
        networkmanager_strongswan
      ];
    };

    firewall = {
      enable = true;

      allowedTCPPorts = [
        22
        3000
        32400
        2049
        4444
        4000
      ];
    };
  };

  # ------------------------------------------------------------------------------------------
  # Services
  # ------------------------------------------------------------------------------------------

  services = {
    pulseaudio.enable = false;

    # Enable the X11 windowing system.
    xserver = {
      enable = true;
      # Configure keymap in X11
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    # Enable touchpad support (enabled default in most desktopManager).
    libinput.enable = true;

    # Enable automatic login for the user.
    displayManager = {
      autoLogin = {
        enable = true;
        user = data.username;
      };

      gdm = {
        enable = true;

        autoLogin = {
          delay = 0;
        };
      };
    };

    gnome.gnome-keyring = {
      enable = true;
    };

    dbus.packages = [
      pkgs.gnome-keyring
      pkgs.gcr
    ];

    # Enable the OpenSSH daemon.
    openssh = {
      enable = true;
      settings = {
        UseDns = true;
        PasswordAuthentication = false;
      };
    };

    udisks2.enable = true;

    gvfs.enable = true; # Mount, trash, and other functionalities

    tumbler.enable = true; # Thumbnail support for images

    earlyoom = {
      enable = true;
      freeSwapThreshold = 2;
      freeMemThreshold = 2;
      extraArgs = [
        "-g"
        "--avoid"
        "^(X|plasma.*|konsole|kwin|hyprland|waybar|keymapper|hyprlock|hyprsunset|hypridle|hyprdynamicmonitors)$"
        "--prefer"
        "^(obsidian|electron|libreoffice|gimp|vlc|spotify|chrome|code|zen-beta)$"
      ];
    };

    pipewire = {
      enable = true;

      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      wireplumber.extraConfig = {
        "51-ryzen-audio-profile" = {
          "monitor.alsa.rules" = [
            {
              matches = [ { "device.name" = "alsa_card.pci-0000_c1_00.6"; } ];
              actions = {
                update-props = {
                  "device.profile" = "pro-audio";
                };
              };
            }
          ];
        };
      };
    };
  };

  systemd = {
    services = {
      # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
      "getty@tty1" = {
        enable = false;
      };

      "autovt@tty1" = {
        enable = false;
      };

      keymapperd = {
        enable = true;
        description = "Start Keymapper Daemon";
        unitConfig = {
          Type = "simple";
        };
        serviceConfig = {
          ExecStart = "${pkgs.keymapper}/bin/keymapperd";
          RestartSec = 5;
        };
        wantedBy = [ "multi-user.target" ];
      };
    };

    # CRON Jobs Equivalents
    timers = { };

    # File Watcher
    paths = { };
  };

  # ------------------------------------------------------------------------------------------
  # Kernel & Bootloader
  # ------------------------------------------------------------------------------------------

  boot = {
    resumeDevice = "/nix/store";

    kernelPackages = pkgs.linuxPackages_latest;

    kernel.sysctl."vm.overcommit_memory" = "1";

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
    ];

    tmp.cleanOnBoot = true;
  };

  # ------------------------------------------------------------------------------------------
  # Security
  # ------------------------------------------------------------------------------------------

  security = {
    sudo = {
      enable = true;
      extraRules = [
        {
          users = [ data.username ];
          commands = [
            {
              command = "/run/current-system/specialisation/light/bin/switch-to-configuration";
              options = [ "NOPASSWD" ];
            }
            {
              command = "/nix/var/nix/profiles/system/bin/switch-to-configuration";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };

    pam.services = {
      sudo = {
        fprintAuth = true;

        rules.auth.fprintd.settings = {
          max_tries = 1;
          timeout = 3;
          # timeout keeps the fallback to password fast if fprintd is slow.
        };
      };

      hyprlock = { };

      gdm = {
        enable = true;
        enableGnomeKeyring = true;

        fprintAuth = true;
      };
    };

    rtkit.enable = true;
  };

  # ------------------------------------------------------------------------------------------
  # Hardware
  # ------------------------------------------------------------------------------------------

  hardware = {
    # Enable Bluetooth
    bluetooth = {
      enable = true;
      powerOnBoot = true;

      settings = {
        General = {
          # Shows battery charge of connected devices on supported
          # Bluetooth adapters. Defaults to 'false'.
          Experimental = true;

          Enable = "Source,Sink,Media,Socket";

          # When enabled other devices can connect faster to us, however
          # the tradeoff is increased power consumption. Defaults to
          # 'false'.
          FastConnectable = false;
        };

        Policy = {
          # Enable all controllers when they are found. This includes
          # adapters present on start as well as adapters that are plugged
          # in later on. Defaults to 'true'.
          AutoEnable = true;
        };
      };
    };
  };

  # ------------------------------------------------------------------------------------------
  # Programs & Generic Installs
  # ------------------------------------------------------------------------------------------

  # Fonts
  fonts = {
    packages = with pkgs; [
      corefonts
      vista-fonts
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      mplus-outline-fonts.githubRelease
      fira-code
      nerd-fonts.fira-code
      fira-code-symbols
      work-sans
      dina-font
      dejavu_fonts
      dejavu_fontsEnv
      geist-font
    ];
  };

  # List packages installed in system profile. To search, run: `nix search wget`
  environment.systemPackages =
    (with pkgs; [
      wget
      sl
      bash
      curl
      jq
      bc
      ddcutil
      gnumake
      docker
      coreutils-full
      systemd
      home-manager
      udiskie
      keymapper # Keyboard remapping
      # Handle Windows Filesystem NTFS
      fuse
      ntfs3g
      # ---
      gparted # Partition Manager
      xclip # Clipboard Manager
      gedit
      gvfs # Virtual Filesystem Support Library
      xarchiver # Archive manager (backend for thunar-archive-plugin)[]
      libnotify # Notification Daemon
      rclone # Data Syncing
      localsend # File Sharing
      stu # S3 TUI File Browser

      kdePackages.dolphin # File Manager

      kdePackages.ark # Archive Manager
      kdePackages.dolphin-plugins # Plugins for Dolphin
      kdePackages.ffmpegthumbs # Video thumbnails / previews in Dolphin
      kdePackages.kompare # Graphical File Differences Tool
      kdePackages.qtsvg # Icons (for Dolphin)
      kdePackages.kio # Network File System (Dolphin)
      kdePackages.kio-extras # Extra protocols support (sftp, fish and more)
      kdePackages.kservice # kbuildsycoca6 — rebuild Dolphin app associations cache

      pkgs.croc # File Transfer tool
    ])
    ++ (with unstable; [ kitty ])
    ++ (with inputs; [
      agenix.packages.${system}.default
    ]);

  # Dolphin "Open with" / file associations need an applications.menu outside Plasma.
  # https://github.com/NixOS/nixpkgs/issues/409986
  environment.etc."xdg/menus/applications.menu".source =
    "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  programs = {
    zsh.enable = true;

    xfconf.enable = true;

    thunar = {
      enable = true;

      plugins =
        (with pkgs.xfce; [
          thunar-archive-plugin # Archive management
          thunar-volman # Management of removable drives and media
          thunar-media-tags-plugin # Media tag management
          thunar-vcs-plugin # Git Support
        ])
        ++ (with unstable; [
          thunar-shares-plugin
        ]);
    };

    seahorse.enable = true;

    ssh = {
      # enable = true;
    };

    git = {
      enable = true;
      config = {
        core = {
          editor = "zeditor --new --wait";
        };

        init = {
          defaultBranch = "main";
        };

        push.autoSetupRemote = true;

        credential.helper = "libsecret";

        help = {
          autocorrect = true;
        };
      };
    };

    hyprland = {
      enable = true;
      xwayland.enable = true;

      package = hyprlandPackages.hyprland;

      portalPackage = hyprlandPackages.xdg-desktop-portal-hyprland;
    };

    nix-ld = {
      enable = true;
      libraries = [ ];
    };
  };

  xdg.portal = {
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.kdePackages.xdg-desktop-portal-kde
      # hyprlandPackages.xdg-desktop-portal-hyprland
    ];

    config = {
      kde.default = [
        "kde"
        "gtk"
      ];
      kde."org.freedesktop.portal.FileChooser" = [ "kde" ];
      kde."org.freedesktop.portal.OpenURI" = [ "kde" ];

      hyprland.default = [
        "hyprland"
        "kde"
        "gtk"
      ];
      hyprland."org.freedesktop.portal.FileChooser" = [ "kde" ];
      hyprland."org.freedesktop.portal.OpenURI" = [ "kde" ];
    };
  };

  # ---------------------------------------------------------------------------------------------------------------------------------------------------------------

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).

  system.stateVersion = "25.11";
}
