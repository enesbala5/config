{
  config,
  lib,
  inputs,
  system,
  ...
}:

let
  cfg = config.modules.home.codex;

  # Codex comes from OpenAI's own flake, pinned to a release tag in flake.nix.
  # Its dev flake reads the version straight from codex-rs/Cargo.toml and builds
  # the workspace with its own nixpkgs + rust-overlay toolchain, so the client
  # tracks upstream exactly instead of nixpkgs-unstable's lagging `codex`.
  #
  # To bump: change the tag in flake.nix, then `nix flake update codex` (or
  # `nix flake lock`) and rebuild. If codex-rs/Cargo.lock changed, upstream's
  # own `cargoLock.outputHashes` build fails; that belongs to their flake.
  pinnedCodex = inputs.codex.packages.${system}.default;
in
{
  options.modules.home.codex.package = lib.mkOption {
    type = lib.types.package;
    default = pinnedCodex;
    defaultText = lib.literalExpression "inputs.codex.packages.\${system}.default";
    description = "The Codex CLI package to wrap (see flake.nix for the pin).";
  };
}
