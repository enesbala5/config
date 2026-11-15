{
  pkgs,
  lib,
  config,
  data,
  ...
}:
let
  lid-inhibit = pkgs.writeShellApplication {
    name = "lid-inhibit";
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
      exec ${pkgs.bash}/bin/bash ${data.configDirectory}/scripts/power/lid-inhibit "$@"
    '';
  };
in
{
  home.packages = [ lid-inhibit ];

  xdg.desktopEntries.lid-inhibit = {
    name = "Ignore Lid";
    genericName = "Ignore lid-close suspension";
    comment = "Toggle one hour without lid-close suspension; idle suspend still works";
    # Absolute path avoids depending on the launcher's icon-theme lookup.
    icon = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/caffeine.svg";
    exec = lib.getExe lid-inhibit;
    terminal = false;
    categories = [ "Utility" ];
    settings.Keywords = "lid-inhibit;ignore lid;lid switch;prevent suspend;clamshell;";
    actions.duration = {
      name = "Choose duration";
      exec = "${lib.getExe lid-inhibit} menu";
    };
  };
}
