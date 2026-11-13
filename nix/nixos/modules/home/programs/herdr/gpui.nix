{
  config,
  lib,
  pkgs,
  inputs,
  system,
  ...
}:
let
  cfg = config.modules.home.herdr;
  herdr-gpui = inputs.herdr-gpui.packages.${system}.default;
in
{
  options.modules.home.herdr.gpui = lib.mkEnableOption "Herdr GPUI desktop client";

  config = lib.mkIf (cfg.enable && cfg.gpui) {
    # Ship the binary/icons, but rewrite the .desktop Name so it does not
    # collide with herdr-app ("Herdr Desktop") in the app launcher.
    home.packages = [
      (pkgs.symlinkJoin {
        name = "herdr-gpui";
        paths = [ herdr-gpui ];
        postBuild = ''
          rm -rf $out/share/applications
          mkdir -p $out/share/applications
          ${pkgs.gnused}/bin/sed 's/^Name=Herdr$/Name=Herdr GPUI/' \
            ${herdr-gpui}/share/applications/herdr-gpui.desktop \
            > $out/share/applications/herdr-gpui.desktop
        '';
      })
    ];
  };
}
