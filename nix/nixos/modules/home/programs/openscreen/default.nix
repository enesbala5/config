{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  options.modules.home.openscreen.enable = lib.mkEnableOption "Openscreen screen recorder and editor";

  config = lib.mkIf config.modules.home.openscreen.enable {
    home.packages = [ inputs.openscreen.packages.${pkgs.stdenv.hostPlatform.system}.openscreen ];
  };
}
