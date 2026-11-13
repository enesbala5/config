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
  desktopModsSrc = "${data.configDirectory}/tools/herdr/desktop/mods";
  # herdr-app's shipped SVG often fails to show in launchers; reuse the
  # GPUI artwork (same brand mark) under the herdr-app icon name, with the
  # graphite mark ~10% darker so the launcher tile reads a bit denser.
  herdrGpuiSvg =
    "${inputs.herdr-gpui.packages.${system}.default}/share/icons/hicolor/scalable/apps/herdr-gpui.svg";
  herdrIcon = pkgs.runCommand "herdr-app.svg" { } ''
    ${pkgs.gnused}/bin/sed 's/#303438/#2b2e32/g' ${herdrGpuiSvg} > $out
  '';
  # Shipped mods under ~/.config/herdr-app/mods are restored on every
  # herdr-app start. Re-apply every folder in tools/herdr/desktop/mods/
  # after launch so hot-reload picks them up.
  herdrAppDesktop = pkgs.writeShellScriptBin "herdr-app-desktop" ''
    set -euo pipefail
    src=${lib.escapeShellArg desktopModsSrc}
    dest_root="$HOME/.config/herdr-app/mods"
    apply_mods() {
      [ -d "$src" ] || return 0
      for mod in "$src"/*; do
        [ -d "$mod" ] || continue
        name=$(basename "$mod")
        dest="$dest_root/$name"
        mkdir -p "$dest"
        # Only copy files the override ships (main.js, assets); leave
        # Herdr-generated d.ts / jsconfig alone when absent from src.
        find "$mod" -maxdepth 1 -type f -print0 | while IFS= read -r -d '' f; do
          cp -f "$f" "$dest/"
        done
      done
    }
    ${lib.getExe packages.herdr-app} "$@" &
    pid=$!
    for _ in 1 2 3 4 5; do
      sleep 0.4
      apply_mods || true
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
    # of ~/.config/herdr-app stays writable runtime state (desktop/mods are
    # re-applied by the desktop entry wrapper after herdr-app restores shipped mods).
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
