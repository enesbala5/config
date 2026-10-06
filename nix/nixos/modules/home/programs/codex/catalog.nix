{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.home.codex;

  # DeepSeek does not publish the Codex model catalog as a standalone file: it
  # ships inside their setup script, in a `<<'CODEX_MODELS_JSON'` heredoc. Pin
  # the script and carve the JSON out of it at build time, so this repo never
  # carries a 76 KB copy that silently drifts from upstream.
  #
  # Source: https://api-docs.deepseek.com/quick_start/agent_integrations/codex
  # To bump: see README.md.
  deepseekSetup = pkgs.fetchurl {
    url = "https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.sh";
    hash = "sha256-d1ekHOICrdg3d1GNTVxnVxvbAx4xkies68UptvtxryA=";
  };

  # `model_catalog_json` replaces Codex's built-in catalog wholesale. Upstream
  # ships more than we want in it:
  #
  #   * `model_messages.instructions_template` duplicates `base_instructions`,
  #     so the same 17 KB system prompt appears four times across two models.
  #     `base_instructions` itself is required and must be non-empty (empty =>
  #     Codex sends no system prompt at all), so it stays.
  #   * `deepseek-v4-pro` is not wired up; wrapper.nix pins `deepseek-flash`.
  modelsJson = pkgs.runCommand "codex-models.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    awk '/<<.CODEX_MODELS_JSON.$/{f=1;next} f&&/^CODEX_MODELS_JSON$/{exit} f' \
      ${deepseekSetup} > catalog.json
    jq '{ models: [ .models[] | select(.slug == "deepseek-flash") | del(.model_messages) ] }' \
      catalog.json > $out
  '';
in
{
  config = lib.mkIf cfg.enable {
    # Codex only reads this file, so a read-only store symlink is fine.
    # The rest of ~/.codex (config.toml, auth.json, hooks, sessions) stays
    # user-owned and writable: Codex rewrites config.toml at runtime for hook
    # and project trust, so home-manager must not take it over.
    home.file.".codex/models.json".source = modelsJson;
  };
}
