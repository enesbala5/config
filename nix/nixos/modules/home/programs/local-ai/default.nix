{
  config,
  lib,
  ...
}:

# Single source of truth for the home-server llama.cpp endpoint, so every
# coding agent on this machine points at the same URL and model id. Options
# only — each harness's adapter (pi's models.json, opencode's provider block)
# reads these and stays a thin shim.
#
# The server side lives in nix/nixos/hosts/home-server/modules/ai: host, port
# and contextSize here must match homeServer.ai there. That module is on the
# home-server/local-ai-vulkan branch, which is why this file duplicates the
# numbers instead of importing them.
#
# Harnesses that cannot be configured from Nix read misc/ai/README.md.
let
  cfg = config.modules.home.localAi;
in
{
  options.modules.home.localAi = {
    enable = lib.mkEnableOption "home-server local inference for coding agents";

    host = lib.mkOption {
      type = lib.types.str;
      default = "home-server";
      description = ''
        Host that serves llama.cpp. Resolves over Tailscale (MagicDNS), so the
        tailnet must be up on the client. From an Incus guest use 10.0.100.1
        instead: incusbr0 is a trusted interface on the host.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "llama-server port. Only reachable over tailscale0.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${cfg.host}:${toString cfg.port}/v1";
      defaultText = lib.literalExpression ''"http://''${cfg.host}:''${toString cfg.port}/v1"'';
      description = ''
        OpenAI-compatible base URL handed to clients. Override only to route
        through a proxy (for example a Caddy front); the derived value is what
        llama-server serves directly.
      '';
    };

    modelId = lib.mkOption {
      type = lib.types.str;
      default = "qwen";
      description = ''
        Model id clients send and list. Matches homeServer.ai.servedName (the
        -a value llama-server advertises), which defaults to the catalog key.
      '';
    };

    modelName = lib.mkOption {
      type = lib.types.str;
      default = "Qwen3-4B Q4_K_M (home-server)";
      description = "Human-readable label shown in model pickers.";
    };

    contextWindow = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8192;
      description = "Must match homeServer.ai.contextSize, including the KV cache type it implies.";
    };

    maxOutputTokens = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2048;
      description = "Per-request output cap, well under contextWindow so prompt and answer both fit.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.host != "localhost" && cfg.host != "127.0.0.1";
        message = "modules.home.localAi.host must point at the inference host, not this machine";
      }
    ];
  };
}
