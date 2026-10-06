{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.home.codex;
in
{
  config = lib.mkIf cfg.enable {
    # DeepSeek publishes a Codex model catalog declaring context window,
    # reasoning levels, tool formats, etc. `model_catalog_json` (set by the
    # wrapper) points at this file. Codex only reads it, so a read-only store
    # symlink is fine. Source: DeepSeek's official Codex setup script —
    # https://api-docs.deepseek.com/quick_start/agent_integrations/codex
    #
    # The rest of ~/.codex (config.toml, auth.json, hooks, sessions) stays
    # user-owned and writable: Codex rewrites config.toml at runtime for hook
    # and project trust, so home-manager must not take it over.
    home.file.".codex/models.json".source = ./models.json;
  };
}
