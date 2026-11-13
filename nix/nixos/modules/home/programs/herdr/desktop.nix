{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.herdr;
  packages = pkgs.callPackage ./packages.nix { };
in
{
  options.modules.home.herdr.desktop.enable = lib.mkEnableOption "Herdr desktop app and herdr-core";

  config = lib.mkIf (cfg.enable && cfg.desktop.enable) {
    home.packages = [
      packages.herdr-core
      packages.herdr-app
    ];

    xdg.desktopEntries.herdr-app = {
      name = "Herdr Desktop";
      comment = "Terminals and coding agents that keep running";
      exec = "${lib.getExe packages.herdr-app}";
      icon = "herdr-app";
      terminal = false;
      categories = [ "Development" ];
      settings.StartupWMClass = "herdr-app";
    };
  };
}
