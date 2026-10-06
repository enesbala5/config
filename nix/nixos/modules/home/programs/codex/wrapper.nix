{
  config,
  lib,
  pkgs,
  data,
  ...
}:

let
  cfg = config.modules.home.codex;

  # agenix installs this mode 0400 in the user's runtime dir (all home secrets
  # land there — see the map in modules/home/default.nix). Codex reads the key
  # from DEEPSEEK_API_KEY via the provider's env_key, so the secret never
  # enters the nix store or ~/.codex/config.toml.
  keyFile = "/run/user/${toString data.uid}/agenix/deepseek-api-key";

  catalog = "${data.homeDirectory}/.codex/models.json";

  # Codex speaks only the Responses API (wire_api = "chat" is rejected), which
  # DeepSeek serves natively at https://api.deepseek.com. Layering these as -c
  # overrides keeps the user's writable config.toml (MCP servers, hooks, project
  # trust) untouched while making DeepSeek the default. Values are parsed as
  # TOML, hence the inner quoting.
  #
  # The catalog is DeepSeek's data, not ours (see catalog.nix and README.md).
  # It declares its own `minimal_client_version`; package.nix pins the client
  # above that so the two stay in step.
  deepseekOverrides = [
    "-c"
    "model=\"deepseek-flash\""
    "-c"
    "model_provider=\"deepseek\""
    "-c"
    "model_catalog_json=\"${catalog}\""
    "-c"
    "model_providers.deepseek.name=\"deepseek\""
    "-c"
    "model_providers.deepseek.base_url=\"https://api.deepseek.com/\""
    "-c"
    "model_providers.deepseek.wire_api=\"responses\""
    "-c"
    "model_providers.deepseek.env_key=\"DEEPSEEK_API_KEY\""
    "-c"
    "model_reasoning_effort=\"low\""
    "-c"
    "web_search=\"disabled\""
    "-c"
    "show_raw_agent_reasoning=true"
  ];

  # `codex` runs on DeepSeek. Overrides come before "$@" so any user-supplied
  # -c flags still win. `codex-openai` is the escape hatch back to the base
  # config (ChatGPT / OpenAI auth).
  wrappedCodex = pkgs.writeShellScriptBin "codex" ''
    set -eu
    if [ ! -r ${lib.escapeShellArg keyFile} ]; then
      echo "codex: cannot read ${keyFile}" >&2
      exit 1
    fi
    DEEPSEEK_API_KEY="$(cat ${lib.escapeShellArg keyFile})"
    export DEEPSEEK_API_KEY
    exec ${lib.getExe cfg.package} ${lib.escapeShellArgs deepseekOverrides} "$@"
  '';

  openaiCodex = pkgs.writeShellScriptBin "codex-openai" ''
    exec ${lib.getExe cfg.package} "$@"
  '';
in
{
  config = lib.mkIf cfg.enable {
    programs.codex.package = wrappedCodex;
    home.packages = [ openaiCodex ];
  };
}
