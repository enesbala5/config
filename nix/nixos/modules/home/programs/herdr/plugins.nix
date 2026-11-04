{
  config,
  lib,
  inputs,
  data,
  system,
  ...
}:
let
  cfg = config.modules.home.herdr;
  herdrPkg = inputs.nixpkgs-herdr.legacyPackages.${system}.herdr;
in
{
  config = lib.mkIf cfg.enable {
    # Plugin registration lives in ~/.config/herdr/plugins.json, which Herdr
    # rewrites, so home-manager cannot symlink it. Link the local plugin during
    # activation. Idempotent, and a failure here does not fail the activation.
    home.activation.herdrLinkAgentHead = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      herdr_bin="${herdrPkg}/bin/herdr"
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
