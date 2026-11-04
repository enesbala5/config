{
  config,
  lib,
  inputs,
  data,
  system,
  ...
}:
let
  cfg = config.modules.home.vicinae;
in
{
  # Flake module writes settings through VICINAE_OVERRIDES and disables HM's
  # built-in programs/vicinae, which still emits the pre-0.17 vicinae.json.
  # The input-server wrapper stays on the host via vicinae.nixosModules.default.
  imports = [ inputs.vicinae.homeManagerModules.default ];

  options.modules.home.vicinae.enable = lib.mkEnableOption "Vicinae";

  # Schema: https://www.vicinae.com/schemas/config.json
  config = lib.mkIf cfg.enable {
    programs.vicinae = {
      enable = true;

      # Defaults true. Only takes effect for browsers HM actually manages.
      enableFirefoxIntegration = true;
      enableChromeIntegration = true;

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

        font.normal = {
          size = 10;
          family = "Geist Medium";
        };

        theme = {
          light = {
            # Stylix also sets this to "stylix". Keep nord-light.
            name = lib.mkForce "nord-light";
            icon_theme = "Bibata-Modern-Classic";
          };

          dark = {
            name = lib.mkForce "stylix";
            icon_theme = "Bibata-Modern-Classic";
          };
        };

        launcher_window = {
          # Stylix sets this from stylix.opacity.popups (0.8).
          opacity = lib.mkForce 0.85;
        };

        favorites = [
          "applications:zen-beta"
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
          files = {
            entrypoints.search.alias = "f";

            preferences = {
              autoIndexing = true;
              excludedIndexingPaths = [
                "${data.homeDirectory}/.config/"
                "${data.homeDirectory}/.local/"
                "${data.homeDirectory}/.ssh/"
                "${data.homeDirectory}/.cache/"
                "${data.homeDirectory}/.cursor/"
              ];
              indexingPaths = [ "${data.homeDirectory}/" ];
              watcherPaths = "";
            };
          };

          clipboard = {
            enabled = true;

            entrypoints.history.preferences.defaultAction = "copy";

            preferences = {
              encryption = false;
              eraseOnStartup = false;
              ignorePasswords = false;
              monitoring = true;
            };
          };

          applications = {
            entrypoints = {
              google-drive.alias = "gdrive";
              "org.gnome.seahorse.Application".alias = "seahorse";
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
            entrypoints.devices.alias = "bluetooth";
          };

          "@botkooper/vicinae-extension-power-profile-0" = {
            entrypoints.power-profile.alias = "power";
          };

          "@dagimg-dot/vicinae-extension-wifi-commander-0" = {
            entrypoints.scan-wifi.alias = "wifi";
          };
        };
      };

      extensions = with inputs.vicinae-extensions.packages.${system}; [
        # bluetooth  # removed upstream: fails node-gyp / dbus-next
        nix
        power-profile
        wifi-commander
        # systemd
        # player-pilot
        port-killer
        # github
        # flathub-search

        ssh
        zed-recents
        hypr
        agent-skills-sh
      ];
    };
  };
}
