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

    # Herdr has no home-manager module for its config. Only these files are
    # symlinked; the rest of each directory is runtime state and stays writable.
    home.file = {
      ".config/herdr/config.toml" = {
        source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/config.toml";
      };

      ".config/herdr-auto-title/config.env" = {
        source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/plugins/auto-title/config.env";
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
