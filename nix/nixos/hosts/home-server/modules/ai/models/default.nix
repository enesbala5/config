{ lib, ... }:

{
  imports = [
    ./qwen
    ./mistral
    ./deepseek
  ];

  options.homeServer.ai.models = {
    directory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ai/models";
      description = "Where GGUF weights are downloaded. Keep off the Nix store.";
    };

    available = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            displayName = lib.mkOption {
              type = lib.types.str;
              description = "Human-readable name for logs and docs.";
            };
            file = lib.mkOption {
              type = lib.types.str;
              description = "Filename under homeServer.ai.models.directory.";
            };
            url = lib.mkOption {
              type = lib.types.str;
              description = "Direct download URL for the GGUF.";
            };
            notes = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Fit / performance notes for this card.";
            };
          };
        }
      );
      default = { };
      description = "Catalog of optional models. Only the selected homeServer.ai.model is downloaded.";
    };
  };
}
