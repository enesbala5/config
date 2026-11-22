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
  # The published gallery repo is a submodule of this config and is the source
  # of truth for the desktop mods and the T3 worktrees layout. A submodule
  # update followed by a rebuild picks up published changes without copying
  # files into this repo a second time.
  gallerySrc = "${data.configDirectory}/herdr-t3-worktrees";
  desktopModsSrc = "${gallerySrc}/mods";
  # herdr-app's shipped SVG often fails to show in launchers; reuse the
  # GPUI artwork (same brand mark) under the herdr-app icon name, with the
  # graphite mark ~10% darker so the launcher tile reads a bit denser.
  herdrGpuiSvg =
    "${inputs.herdr-gpui.packages.${system}.default}/share/icons/hicolor/scalable/apps/herdr-gpui.svg";
  herdrIcon = pkgs.runCommand "herdr-app.svg" { } ''
    ${pkgs.gnused}/bin/sed 's/#303438/#2b2e32/g' ${herdrGpuiSvg} > $out
  '';
  # Shipped mods under ~/.config/herdr-app/mods are restored on every
  # herdr-app start. Re-apply every folder in the gallery submodule's mods/
  # after launch so hot-reload picks them up. Renamed mods (t3-picker,
  # t3-toast, ...) never replace a shipped mod; the layout points at them.
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
        find "$mod" -maxdepth 1 -type f -print0 | while IFS= read -r -d "" f; do
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
  options.modules.home.herdr.desktop.enable = lib.mkEnableOption "Herdr desktop app";

  config = lib.mkIf (cfg.enable && cfg.desktop.enable) {
    # The desktop app is a client of herdr-core, so pull the core in with it.
    modules.home.herdr.core.enable = true;

    home.packages = [ packages.herdr-app ];

    # Same pattern as the TUI config.toml: the keys and the published T3
    # worktrees layout are managed; the rest of ~/.config/herdr-app stays
    # writable runtime state (mods are re-applied by the desktop entry wrapper
    # after herdr-app restores shipped mods). Clicks still live in layouts/.state.
    home.file.".config/herdr-app/keys.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/desktop/keys.json";
    };

    # Stylix-derived themes (circus / google-light base16 palettes). Additive
    # only: settings.json, shared.json, layouts/ and mods/ are left untouched;
    # pick the pair once in Herdr's appearance settings and it follows the
    # system light/dark polarity from there.
    home.file.".config/herdr-app/themes/stylix-dark.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/themes/stylix-dark.json";
    };
    home.file.".config/herdr-app/themes/stylix-light.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/themes/stylix-light.json";
    };
    home.file.".config/herdr-app/layouts/herdr-t3-worktrees.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${gallerySrc}/layouts/herdr-t3-worktrees.json";
    };
    home.file.".config/herdr-app/layouts/herdr-t3-worktrees.svg" = {
      source = config.lib.file.mkOutOfStoreSymlink "${gallerySrc}/layouts/herdr-t3-worktrees.svg";
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
