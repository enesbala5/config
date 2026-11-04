{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.figmaLinux;
in
{
  options.modules.home.figmaLinux.enable = lib.mkEnableOption "Figma Linux";

  # nixpkgs 26.05 has figma-linux 0.11.5, the current upstream release
  # (same version on nixpkgs-unstable). The wrapper adds Ozone/Wayland
  # flags when NIXOS_OZONE_WL is set, which base-configuration already does.
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.figma-linux ];
  };
}
