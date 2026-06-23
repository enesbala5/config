{
  pkgs,
  config,
  inputs,
  system,
  unstable,
  data,
  ...
}:
let
in
{
  home.packages =
    (with pkgs; [
      # System
      # ------------------------------------------------------------------------------------------
      dunst # Notification Interface
      brillo # Brightness Control

      hyprsunset # Night Light
      hypridle # Idle State
      hyprlock # Lock Screen

      # Documents
      #  ------------------------------------------------------------------------------------------
      libreoffice-qt
      hunspell
      hunspellDicts.en_US

      # Development
      # ------------------------------------------------------------------------------------------
      beekeeper-studio # Database Management
      insomnia # API Client
      neovim # Neovim
      vim # Vim

      # Graphic Design & Video Editing
      # ------------------------------------------------------------------------------------------
      shotcut # Video Editor
      kdePackages.kdenlive # Video Editor

      # Tools
      # ------------------------------------------------------------------------------------------
      obsidian # Note Taking App
      typora # Markdown Note Taking & PDF Exporting
      nomacs # Image Viewer
      remmina
      firefox

      markdown-oxide

      # Functionality
      # ------------------------------------------------------------------------------------------
      wtype # Needed for Text Insertion in Waybar (for Handy TTS)
    ])
    # Unstable packages
    # ---
    ++ (with unstable; [
      spotify
      telegram-desktop

      # IDE
      vscode
      cursor-cli

      # TTS
      handy
    ])
    # Flakes
    # ---
    ++ (with inputs; [
      affinity-nix.packages.${system}.default
      hyprshutdown.packages.${system}.default
      zed-editor.packages.${system}.default
    ]);

  programs = {
    zen-browser.enable = true;

    obs-studio = {
      enable = true;

      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-backgroundremoval
        obs-pipewire-audio-capture
        obs-vaapi # optional AMD hardware acceleration
        obs-gstreamer
        obs-vkcapture
      ];
    };

    ssh = {
      enable = true;

      matchBlocks."*" = {
        forwardAgent = false;
        addKeysToAgent = "yes";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };

      includes = [ config.age.secrets.ssh-config.path ];
    };
  };

  services = {
    kdeconnect.enable = true;

    # Audio
    easyeffects = {
      enable = true;

      package = pkgs.easyeffects;
      preset = "HifiScan+EEGuide"; # Profile from framework-dsp repository - Installation guide at README
    };

    vicinae = {
      # Schema: https://www.vicinae.com/schemas/config.json
      # Default Config: `vicinae config default`

      enable = true;

      systemd = {
        enable = true;
        autoStart = true;

        environment = {
          USE_LAYER_SHELL = 1;
        };
      };

      settings = {
        close_on_focus_loss = false;
        consider_preedit = true;
        pop_to_root_on_close = true;
        search_files_in_root = true;

        favicon_service = "twenty";

        font = {
          rendering = "native";

          normal = {
            size = 10;
            family = "Geist Medium";
          };
        };

        theme = {
          light = {
            name = "nord-light";
            icon_theme = "Bibata-Modern-Classic";
          };

          dark = {
            name = "stylix";
            icon_theme = "Bibata-Modern-Classic";
          };
        };

        launcher_window = {
          opacity = 0.85;
        };

        favorites = [
          "applications:zen-beta"
          "applications:spotify"
          "applications:obsidian"
          "applications:cursor"
          "applications:dev.zed.Zed-Nightly.desktop"
          "applications:whatsApp"
          "applications:google-drive"
          "@Gelei/vicinae-extension-bluetooth-0:devices"
        ];

        fallbacks = [
          "shortcuts:6449e19e-177d-462b-86d7-ca7fb01b9753" # Google Search
          "files:search"
        ];

        telemetry = {
          system_info = false;
        };

        providers = {
          clipboard = {
            enabled = true;

            preferences = {
              encryption = false;
              eraseOnStartup = false;
              ignorePasswords = false;
              monitoring = true;
            };
          };

          files = {
            preferences = {
              autoIndexing = true;
              excludedPaths = "";
              paths = "${data.homeDirectory}/";
              watcherPaths = "";
            };
          };

          applications = {
            entrypoints = {
              google-drive = {
                alias = "gdrive";
              };
              "org.gnome.seahorse.Application" = {
                alias = "seahorse";
              };
            };
          };

          power = {
            entrypoints = {
              power-off = {
                preferences = {
                  confirm = true;
                  customProgram = "${data.configDirectory}/scripts/power/shutdown.sh";
                };
              };
              reboot = {
                preferences = {
                  confirm = true;
                  customProgram = "${data.configDirectory}/scripts/power/reboot.sh";
                };
              };
              logout = {
                preferences = {
                  confirm = true;
                  customProgram = "pidof hyprlock --no-fade-in || hyprlock";
                };
              };
            };
          };

          "@Gelei/vicinae-extension-bluetooth-0" = {
            entrypoints = {
              devices = {
                alias = "bluetooth";
              };
            };
          };

          "@botkooper/vicinae-extension-power-profile-0" = {
            entrypoints = {
              power-profile = {
                alias = "power";
              };
            };
          };

          "@dagimg-dot/vicinae-extension-wifi-commander-0" = {
            entrypoints = {
              scan-wifi = {
                alias = "wifi";
              };
            };
          };
        };
      };

      extensions = with inputs.vicinae-extensions.packages.${pkgs.stdenv.hostPlatform.system}; [
        bluetooth
        nix
        power-profile
        wifi-commander
        # systemd
        # player-pilot
        port-killer
        # github
        # flathub-search

        # Raycast Extensions
        # ---
        # google-fonts
      ];
    };
  };

  xdg = {
    mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = "thunar.desktop";
        "x-scheme-handler/http" = [
          "zen-beta.desktop"
          "helium.desktop"
          "google-chrome.desktop"
        ];
        "x-scheme-handler/https" = [
          "zen-beta.desktop"
          "helium.desktop"
          "google-chrome.desktop"
        ];
        "text/html" = [
          "zen-beta.desktop"
          "helium.desktop"
          "google-chrome.desktop"
        ];
        "text/plain" = [
          "dev.zed.Zed-Nightly.desktop"
          "dev.zed.Zed.desktop"
        ];
        "text/markdown" = [
          "dev.zed.Zed-Nightly.desktop"
          "dev.zed.Zed.desktop"
          "org.gnome.gedit.desktop"
        ];
        "image/jpeg" = [
          "org.nomacs.ImageLounge.desktop"
          "zen-beta.desktop"
          "helium.desktop"
          "google-chrome.desktop"
        ];
        "image/png" = [
          "org.nomacs.ImageLounge.desktop"
          "zen-beta.desktop"
          "helium.desktop"
          "google-chrome.desktop"
        ];
        "image/svg+xml" = [
          "org.nomacs.ImageLounge.desktop"
          "zen-beta.desktop"
          "helium.desktop"
          "google-chrome.desktop"
        ];
        "video/mp4" = [
          "vlc.desktop"
          "org.shotcut.Shotcut.desktop"
        ];
        "video/mp3" = [
          "vlc.desktop"
          "zen-beta.desktop"
          "helium.desktop"
        ];
        "video/webm" = [
          "vlc.desktop"
          "org.shotcut.Shotcut.desktop"
          "helium.desktop"
          "google-chrome.desktop"
        ];
        "application/pdf" = [
          "zen-beta.desktop"
          "helium.desktop"
          "google-chrome.desktop"
        ];
      };
    };

    configFile."mimeapps.list".force = true;

    # Workaround to support "Open in Terminal" in Thunar
    configFile."xfce4/helpers.rc".text = ''
      TerminalEmulator=kitty
    '';

    userDirs = {
      enable = true;
      desktop = "${data.homeDirectory}/desktop";
      documents = "${data.homeDirectory}/documents";
      download = "${data.homeDirectory}/downloads";
      pictures = "${data.homeDirectory}/gdrive/Media/Temporary";
      videos = "${data.homeDirectory}/gdrive/Media/Temporary";
      music = null;
      publicShare = null;
      templates = null;
    };

    desktopEntries = {

      cursor = {
        name = "Cursor";
        genericName = "Code Editor";
        icon = "${data.configDirectory}/tools/cursor/icon.png";
        exec = "appimage-run ${data.homeDirectory}/programs/cursor/cursor.AppImage";
        type = "Application";
        terminal = false;
        categories = [
          "Utility"
          "Development"
        ];
      };

      helium = {
        name = "Helium";
        genericName = "Web Browser";
        icon = "helium";
        exec = "hyprctl dispatch exec ${inputs.helium-browser.packages.${system}.default}/bin/helium";
        type = "Application";
        terminal = false;
        mimeType = [
          "text/html"
          "text/xml"
          "application/xhtml+xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ];
        categories = [
          "Network"
          "WebBrowser"
        ];
      };

      pencil = {
        name = "Pencil";
        genericName = "Vector Graphics Editor";
        icon = "${data.configDirectory}/tools/pencil/icon.png";
        exec = "appimage-run ${data.homeDirectory}/programs/pencil/pencil.AppImage";
        type = "Application";
        terminal = false;
        categories = [
          "Utility"
          "Graphics"
        ];
      };

      analytics = {
        name = "Analytics";
        icon = "${data.configDirectory}/tools/links/analytics.png";
        settings.URL = "https://analytics.enesbala.com";
        genericName = "Analytics Dashboard";
        type = "Link";
        terminal = null;
      };

      status-monitoring = {
        name = "Status Monitoring";
        icon = "${data.configDirectory}/tools/links/status-monitoring.png";
        settings.URL = "https://status.enesbala.com";
        genericName = "Status Page";
        type = "Link";
        terminal = null;
      };

      mail = {
        name = "Zoho Mail";
        icon = "${data.configDirectory}/tools/links/zoho-mail.png";
        settings.URL = "https://mail.zoho.eu";
        genericName = "Email Client";
        type = "Link";
        terminal = null;
      };

      toggl-track = {
        name = "Toggl Track";
        icon = "${data.configDirectory}/tools/links/toggl-track.png";
        settings.URL = "https://track.toggl.com/timer";
        genericName = "Time Tracker";
        type = "Link";
        terminal = null;
      };

      google-tasks = {
        name = "Google Tasks";
        icon = "${data.configDirectory}/tools/links/google-tasks.png";
        settings.URL = "https://tasks.google.com/tasks";
        genericName = "Task Manager TODO";
        type = "Link";
        terminal = null;
      };

      hetzner-server = {
        name = "Hetzner Server: Coolify";
        icon = "${data.configDirectory}/tools/links/coolify.png";
        settings.URL = "https://server.enesbala.com";
        genericName = "Coolify Server Management";
        type = "Link";
        terminal = null;
      };

      home-server = {
        name = "Home Server: Coolify";
        icon = "${data.configDirectory}/tools/links/coolify.png";
        settings.URL = "https://host.enesbala.com";
        genericName = "Coolify Server Management";
        type = "Link";
        terminal = null;
      };

      whatsApp = {
        name = "WhatsApp";
        icon = "${data.configDirectory}/tools/links/whatsApp.png";
        settings.URL = "https://web.whatsapp.com";
        genericName = "WhatsApp Web";
        type = "Link";
        terminal = null;
      };

      # spotify = {
      #   name = "Spotify";
      #   icon = "${data.configDirectory}/tools/links/spotify.png";
      #   settings.URL = "https://open.spotify.com";
      #   genericName = "Spotify";
      #   type = "Link";
      #   terminal = null;
      # };

      google-drive = {
        name = "Google Drive";
        icon = "${data.configDirectory}/tools/links/google-drive.png";
        exec = "xdg-open ${data.homeDirectory}/gdrive";
        genericName = "Google Drive";
        type = "Application";
        terminal = false;
      };

      google-drive-web = {
        name = "Google Drive Web";
        icon = "${data.configDirectory}/tools/links/google-drive.png";
        settings.URL = "https://drive.google.com";
        genericName = "Google Drive Web";
        type = "Link";
        terminal = null;
      };

      google-calendar = {
        name = "Google Calendar";
        icon = "${data.configDirectory}/tools/links/google-calendar.png";
        settings.URL = "https://calendar.google.com";
        genericName = "Google Calendar";
        type = "Link";
        terminal = null;
      };

      github = {
        name = "GitHub";
        icon = "${data.configDirectory}/tools/links/github.png";
        settings.URL = "https://github.com";
        genericName = "GitHub";
        type = "Link";
        terminal = null;
      };
    };
  };
}
