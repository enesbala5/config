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
  toastSrc = "${data.configDirectory}/tools/herdr/desktop/mods/toast";
  # herdr-app's shipped SVG often fails to show in launchers; reuse the
  # GPUI artwork (same brand mark) under the herdr-app icon name, with the
  # graphite mark ~10% darker so the launcher tile reads a bit denser.
  herdrGpuiSvg =
    "${inputs.herdr-gpui.packages.${system}.default}/share/icons/hicolor/scalable/apps/herdr-gpui.svg";
  herdrIcon = pkgs.runCommand "herdr-app.svg" { } ''
    ${pkgs.gnused}/bin/sed 's/#303438/#2b2e32/g' ${herdrGpuiSvg} > $out
  '';
  # Shipped mods/toast is restored on every herdr-app start. Re-apply the
  # glass toast after launch so hot-reload picks it up.
  herdrAppDesktop = pkgs.writeShellScriptBin "herdr-app-desktop" ''
    set -euo pipefail
    src=${lib.escapeShellArg toastSrc}
    dest="$HOME/.config/herdr-app/mods/toast"
    apply_toast() {
      mkdir -p "$dest"
      cp -f "$src"/main.js "$src"/*.svg "$dest"/
    }
    ${lib.getExe packages.herdr-app} "$@" &
    pid=$!
    for _ in 1 2 3 4 5; do
      sleep 0.4
      apply_toast || true
    done
    wait "$pid"
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
    # of ~/.config/herdr-app stays writable runtime state (toast is re-applied
    # by the desktop entry wrapper after herdr-app restores the shipped mod).
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
      exec = "${lib.getExe herdrAppDesktop}";
      icon = herdrIcon;
      terminal = false;
      categories = [ "Development" ];
      settings.StartupWMClass = "herdr-app";
    };
  };
}
