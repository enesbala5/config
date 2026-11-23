{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.home.openscreen.enable = lib.mkEnableOption "Openscreen screen recorder and editor";

  config = lib.mkIf config.modules.home.openscreen.enable {
    # The pinned package defaults to Electron 41, which nixpkgs marks insecure.
    home.packages = [ (pkgs.openscreen.override { electron_41 = pkgs.electron_42; }) ];
  };
}
