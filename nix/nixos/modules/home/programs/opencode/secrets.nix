{
  config,
  lib,
  data,
  ...
}:

let
  cfg = config.modules.home.opencode;
in
{
  config = lib.mkIf cfg.enable {
    # opencode deep-merges this extra config layer over config.json at startup,
    # so provider keys / MCP tokens can be added by editing the agenix secret
    # alone (no Nix change). Materialized by the Home Manager agenix module at
    # $XDG_RUNTIME_DIR/agenix (i.e. /run/user/<uid>/agenix).
    home.sessionVariables.OPENCODE_CONFIG = "/run/user/${toString data.uid}/agenix/opencode-secrets.json";
  };
}
