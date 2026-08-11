{
  inputs,
  pkgs,
  config,
  data,
  lib,
  ...
}:
{
  imports = [
    inputs.zen-browser.homeModules.beta
    # Prefer the flake module: it applies settings via VICINAE_OVERRIDES.
    # HM 25.11's built-in module writes obsolete ~/.config/vicinae/vicinae.json
    # which Vicinae >=0.17 no longer reads.
    inputs.vicinae.homeManagerModules.default
    ./programs
  ];

  disabledModules = [ "programs/vicinae.nix" ];

  # Flake module always assigns programs.google-chrome.nativeMessagingHosts when
  # enable=true. HM 25.11 does not declare that option for proprietary Chrome.
  options.programs.google-chrome.nativeMessagingHosts = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    internal = true;
  };

  config = {
    home.sessionVariables = {
      # Allow all GTK apps to find the xfsettingsd GTK sync module so they
      # don't emit "Failed to load module xfsettingsd-gtk-settings-sync" warnings
      # when xfsettingsd broadcasts the Gtk/Modules XSetting.
      GTK_PATH = "${pkgs.xfce.xfce4-settings}/lib/gtk-3.0";
    };

    home.file =
      let
        pbi = pkgs.kdePackages.plasma-browser-integration;
        chromiumHost = "${pbi}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";
      in
      {
        ".config/hypr/hyprlock.conf" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/hypr/hyprlock/configuration.conf";
        };

        ".config/hypr/hypridle.conf" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/hypr/hypridle/configuration.conf";
        };

        ".config/hypr/hyprsunset.conf" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/hypr/hyprsunset/configuration.conf";
        };

        ".config/zed" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/zed";
          recursive = true;
        };

        ".agents/skills" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/misc/skills";
          recursive = true;
        };

        # Plasma Browser Integration native host (Helium)
        ".config/net.imput.helium/NativeMessagingHosts/org.kde.plasma.browser_integration.json".source =
          chromiumHost;
      };

    systemd.user = {
      services = {
        xfsettingsd = {
          Unit = {
            Description = "xfsettingsd";
            After = [ "graphical-session-pre.target" ];
            PartOf = [ "graphical-session.target" ];
          };

          Install.WantedBy = [ "graphical-session.target" ];

          Service = {
            Environment = [
              "PATH=${data.homeDirectory}/bin"
              "GTK_PATH=${pkgs.xfce.xfce4-settings}/lib/gtk-3.0"
            ];
            ExecStart = "${pkgs.xfce.xfce4-settings}/bin/xfsettingsd";
            Restart = "on-abort";
          };
        };
      };
    };
  };
}
