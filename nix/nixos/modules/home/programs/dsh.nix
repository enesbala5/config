{
  config,
  lib,
  inputs,
  system,
  ...
}:
let
  cfg = config.modules.home.dsh;

  # pkgs/dsh.nix pins a pnpm-deps hash that does not match a fetch against
  # the nixpkgs rev in dsh-nix's flake.lock (0e251e24). That fetch reported:
  #
  #   specified: sha256-aySHq0ywTMM5q7YuGHZrV3yQE3bwppgGfWH3wRnHCXk=
  #        got: sha256-ZieCojp4pHCTQdufQftn/BYYaiZRkiEvnWMflw4zyz4=
  #
  # pnpm still exited 0 after curl 23 on two optional linux tarballs
  # (@openai/codex-linux-x64, @anthropic-ai/claude-agent-sdk-linux-x64), so
  # the install contains dangling symlinks. Drop those so the stdenv check
  # passes. Those two optional binaries are absent from this build.
  upstreamPnpmDepsHash = "sha256-aySHq0ywTMM5q7YuGHZrV3yQE3bwppgGfWH3wRnHCXk=";
  pnpmDepsHash = "sha256-ZieCojp4pHCTQdufQftn/BYYaiZRkiEvnWMflw4zyz4=";

  dshPkgs = import "${inputs.dsh-nix.inputs.nixpkgs}" {
    inherit system;
    config.allowUnfree = true;
  };

  dshPkgs' = dshPkgs.extend (
    final: prev: {
      fetchPnpmDeps =
        args:
        prev.fetchPnpmDeps (
          if (args.hash or "") == upstreamPnpmDepsHash then args // { hash = pnpmDepsHash; } else args
        );
    }
  );

  dsh = (dshPkgs'.callPackage "${inputs.dsh-nix}/pkgs/dsh.nix" {
    src = inputs.dsh-nix.inputs.dsh;
  }).overrideAttrs
    (old: {
      postInstall = (old.postInstall or "") + ''
        find "$out" -xtype l -delete
      '';
    });
in
{
  imports = [ inputs.dsh-nix.homeManagerModules.dsh ];

  options.modules.home.dsh.enable = lib.mkEnableOption "DeepSeek Harness (dsh)";

  # In-box profiles only. Spec plugins need a real specsHash, and patch
  # files need a path that exists; add those on the host that uses them.
  config = lib.mkIf cfg.enable {
    programs.dsh = {
      enable = true;
      package = dsh;

      profiles.headless.plugins = [
        "@deepseek-ai/dsh-base"
        "@deepseek-ai/dsh-headless"
      ];

      profiles.web.plugins = [
        "@deepseek-ai/dsh-base"
        "@deepseek-ai/dsh-web-app"
      ];
    };
  };
}
