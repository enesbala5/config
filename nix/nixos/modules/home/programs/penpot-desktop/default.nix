{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.modules.home.penpotDesktop.enable = lib.mkEnableOption "Penpot Desktop";

  config = lib.mkIf config.modules.home.penpotDesktop.enable {
    home.packages = [ pkgs.penpot-desktop ];
  };
}
