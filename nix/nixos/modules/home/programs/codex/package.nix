{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.home.codex;

  version = "0.164.0";

  # OpenAI ships and signs a static-pie musl binary per release. Their Nix flake
  # is a *development* flake whose `packages` output does not build — its
  # cargoLock.outputHashes omits git deps (appcontainer_common and the rest of
  # microsoft/mxc, h3, …) — so pin the release binary instead of the Rust build.
  # No compile, and no upstream binary cache needed.
  #
  # To bump: set `version` and refresh the hash:
  #   nix store prefetch-file --json \
  #     "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz"
  pinnedCodex = pkgs.stdenvNoCC.mkDerivation {
    pname = "codex";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-kN0LA7KK/Lf6czpPc7QT2ykWpHNH79Q/tmnMHHdO6OQ=";
    };

    # The tarball holds a single bare file, not a wrapping directory.
    sourceRoot = ".";
    dontPatchELF = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 codex-x86_64-unknown-linux-musl $out/bin/codex
      runHook postInstall
    '';

    meta = {
      description = "OpenAI Codex command-line interface (official release binary)";
      homepage = "https://github.com/openai/codex";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  options.modules.home.codex.package = lib.mkOption {
    type = lib.types.package;
    default = pinnedCodex;
    defaultText = lib.literalExpression "the pinned OpenAI Codex release binary";
    description = "The Codex CLI package to wrap (see this file for the pin).";
  };
}
