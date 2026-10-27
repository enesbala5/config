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

  # Herdr Agent Icons Max (herdr-radar, MIT). Family name is "Herdr Agent Icons Max".
  # Pin a commit: the file on `main` is not hash-stable.
  # Cmap at this commit is U+E1A0–U+E1BA and U+E1C0–U+E1C5.
  herdrAgentIcons = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/hhdebb/herdr-radar/47c022d4fcfe115e9e45433aa953510a41349111/dist/HerdrAgentIconsMax-Regular.ttf";
    hash = "sha256-G4GZSWsiPQdh/DpJ1bJRC9o43quCyzdYvzmASVvwUnI=";
  };
in
{
  options.modules.home.herdr = {
    enable = lib.mkEnableOption "Herdr";
    gpui = lib.mkEnableOption "Herdr GPUI desktop client";
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      [
        inputs.herdr.packages.${system}.default
        # Auto Title's `herdr plugin install` builds a Go plugin on the machine.
        pkgs.go
        # Agent Head's startup hook runs head.js.
        pkgs.nodejs
      ]
      ++ lib.optional cfg.gpui inputs.herdr-gpui.packages.${system}.default;

    # NixOS fontconfig already scans $XDG_DATA_HOME/fonts (~/.local/share/fonts).
    xdg.dataFile."fonts/HerdrAgentIconsMax-Regular.ttf".source = herdrAgentIcons;

    # Kitty does not pick a private-use font up as a fallback family.
    programs.kitty.settings.symbol_map = "U+E1A0-U+E1BA,U+E1C0-U+E1C5 Herdr Agent Icons Max";
    
    # Herdr has no home-manager module for its config. Only these files are
    # symlinked; the rest of each directory is runtime state and stays writable.
    home.file = {
      ".config/herdr/config.toml" = {
        source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/config.toml";
      };

      ".config/herdr-auto-title/config.env" = {
        source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/plugins/auto-title/config.env";
      };

      ".config/herdr/plugins/config/herdr-bar/config.json" = {
        source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/plugins/herdr-bar/config.json";
      };
    };

    # Plugin registration lives in ~/.config/herdr/plugins.json, which Herdr
    # rewrites, so home-manager cannot symlink it. Link the local plugin during
    # activation. Idempotent, and a failure here does not fail the activation.
    home.activation.herdrLinkAgentHead =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        herdr_bin="${inputs.herdr.packages.${system}.default}/bin/herdr"
        plugin_dir="${data.configDirectory}/tools/herdr/plugins/agent-head"
        registry="$HOME/.config/herdr/plugins.json"
        if [ -x "$herdr_bin" ] && [ -f "$plugin_dir/herdr-plugin.toml" ]; then
          if ! grep -q 'local.agent-head' "$registry" 2>/dev/null; then
            "$herdr_bin" plugin link "$plugin_dir" >/dev/null 2>&1 || true
          fi
        fi
      '';
  };
}
