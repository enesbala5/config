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

    # Home-server llama.cpp endpoint. Kept disabled on purpose: pi is the
    # harness that gets exercised against the local model, and 1.17.7 resolves
    # a custom provider through `npm`, which installs @ai-sdk/openai-compatible
    # into ~/.cache/opencode on first use. Enable after checking the local
    # model actually earns a slot in opencode's agent loop.
    #
    # To enable: move these two lines out of the comment (they belong in the
    # `let` and `config` blocks above respectively) and drop the `#` markers.
    #
    # localAi = config.modules.home.localAi;   # in the let block
    #
    # lib.mkIf localAi.enable {
    #   programs.opencode.settings.provider.home-server = {
    #     name = "Home Server (llama.cpp)";
    #     npm = "@ai-sdk/openai-compatible";
    #     options = {
    #       baseURL = localAi.baseUrl;
    #       # llama-server has no --api-key; the value only satisfies the SDK.
    #       apiKey = "local";
    #     };
    #     models.${localAi.modelId} = {
    #       name = localAi.modelName;
    #       tool_call = true;
    #       reasoning = true;
    #       limit = {
    #         context = localAi.contextWindow;
    #         output = localAi.maxOutputTokens;
    #       };
    #     };
    #   };
    # };
  };
}
