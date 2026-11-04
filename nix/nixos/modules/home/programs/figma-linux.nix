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
  #
  # The nixpkgs desktop file has no MimeType, so "Open with desktop app"
  # never hands figma:// back to the app. This entry replaces it (hiPrio)
  # and registers the scheme. Upstream uses the same handler.
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.figma-linux ];

    xdg.desktopEntries."figma-linux" = {
      name = "Figma Linux";
      comment = "Unofficial Figma desktop application for Linux";
      exec = "${lib.getExe pkgs.figma-linux} %U";
      icon = "figma-linux";
      terminal = false;
      categories = [ "Graphics" ];
      mimeType = [
        "application/figma"
        "x-scheme-handler/figma"
      ];
      settings.StartupWMClass = "figma-linux";
    };

    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/figma" = "figma-linux.desktop";
      "application/figma" = "figma-linux.desktop";
    };
  };
}
