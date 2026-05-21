{
  inputs,
  pkgs,
  config,
  data,
  ...
}:
{
  imports = [
    inputs.zen-browser.homeModules.beta
    inputs.vicinae.homeManagerModules.default
    ./programs
  ];

  home.file = {
    ".config/hypr/hyprlock.conf" = {
      source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/hypr/hyprlock/configuration.conf";
    };

    ".config/hypr/hypridle.conf" = {
      source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/hypr/hypridle/configuration.conf";
    };

    ".config/hypr/hyprsunset.conf" = {
      source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/hypr/hyprsunset/configuration.conf";
    };
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
          Environment = "PATH=${data.homeDirectory}/bin";
          ExecStart = "${pkgs.xfce.xfce4-settings}/bin/xfsettingsd";
          Restart = "on-abort";
        };
      };
    };
  };
}
