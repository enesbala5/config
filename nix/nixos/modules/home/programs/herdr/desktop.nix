{
  config,
  lib,
  pkgs,
  inputs,
  data,
  system,
  ...
}:
let
  cfg = config.modules.home.herdr;
  packages = pkgs.callPackage ./packages.nix { };
  # herdr-app's shipped SVG often fails to show in launchers; reuse the
  # GPUI artwork (same brand mark) under the herdr-app icon name, with the
  # graphite mark ~10% darker so the launcher tile reads a bit denser.
  herdrGpuiSvg =
    "${inputs.herdr-gpui.packages.${system}.default}/share/icons/hicolor/scalable/apps/herdr-gpui.svg";
  herdrIcon = pkgs.runCommand "herdr-app.svg" { } ''
    ${pkgs.gnused}/bin/sed 's/#303438/#2b2e32/g' ${herdrGpuiSvg} > $out
  '';
in
{
  options.modules.home.herdr.desktop.enable = lib.mkEnableOption "Herdr desktop app and herdr-core";

  config = lib.mkIf (cfg.enable && cfg.desktop.enable) {
    home.packages = [
      packages.herdr-core
      packages.herdr-app
    ];

    # Same pattern as the TUI config.toml: only keys.json is managed; the rest
    # of ~/.config/herdr-app stays writable runtime state.
    home.file.".config/herdr-app/keys.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/desktop/keys.json";
    };

    # Cursor → herdr-core OSC 7501 bridge (Desktop Agents sidebar). See
    # tools/herdr/integrations/cursor/README.md. Owns ~/.cursor/hooks.json on
    # desktop hosts; herdr-agent-state.sh stays managed by `herdr integration`.
    home.file.".cursor/herdr-desktop-status.sh" = {
      source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/integrations/cursor/desktop-status.sh";
    };
    home.file.".cursor/hooks.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/integrations/cursor/hooks.json";
    };

    xdg.dataFile."icons/hicolor/scalable/apps/herdr-app.svg".source = herdrIcon;

    xdg.desktopEntries.herdr-app = {
      name = "Herdr Desktop";
      comment = "Terminals and coding agents that keep running";
      exec = "${lib.getExe packages.herdr-app}";
      icon = herdrIcon;
      terminal = false;
      categories = [ "Development" ];
      settings.StartupWMClass = "herdr-app";
    };
  };
}
