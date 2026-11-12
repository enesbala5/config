{
  pkgs,
  lib,
  config,
  data,
  ...
}:
let
  caffeinate = pkgs.writeShellApplication {
    name = "caffeinate";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      pkgs.procps
      pkgs.util-linux
      pkgs.jq
      pkgs.libnotify
      config.programs.vicinae.package
    ];
    text = ''
      exec ${pkgs.bash}/bin/bash ${data.configDirectory}/scripts/power/caffeinate "$@"
    '';
  };
in
{
  home.packages = [ caffeinate ];

  xdg.desktopEntries.caffeinate = {
    name = "Caffeinate";
    genericName = "Keep awake";
    comment = "Toggle one hour without idle dimming, locking or suspend";
    icon = "preferences-desktop-screensaver";
    exec = lib.getExe caffeinate;
    terminal = false;
    categories = [ "Utility" ];
    settings.Keywords = "caffeinate;keep awake;prevent sleep;idle;";
    actions.duration = {
      name = "Choose duration";
      exec = "${lib.getExe caffeinate} menu";
    };
  };
}
