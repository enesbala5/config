{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.home.opencode;
in
{
  config = lib.mkIf cfg.enable {
    # Non-secret provider shape. API keys live in the secret config layer
    # (see secrets.nix), which opencode deep-merges over this at startup.
    programs.opencode.settings.provider.anthropic.options = {
      baseURL = "https://api.synterolink.com/v1";
    };
  };
}
