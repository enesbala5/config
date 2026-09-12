# Hermes Desktop (Electron) + `hermes` CLI, via the flake's Home Manager module.
#
# Deliberately no `services.hermes-agent` here: without it the desktop app
# starts and owns its own backend, so no gateway/backend daemon runs. The
# `hermes` CLI is installed so first-run setup and config edits work normally
# (nothing sets HERMES_MANAGED, so the CLI is not blocked).
{
  inputs,
  system,
  ...
}:
let
  # The upstream, fully-built agent package. Built by the hermes-agent flake
  # against its own pinned nixpkgs, and used unchanged for the `hermes` CLI
  # (i.e. the module's default `programs.hermes-agent.package`).
  hermesFull = inputs.hermes-agent.packages.${system}.default;

  # hermes-agent's pinned nixpkgs rev, as resolved through *our* flake.lock.
  #
  # We need it because upstream `nix/desktop.nix` compiles node-pty against
  # the Electron from this package set, and our own nixpkgs inputs carry a
  # different Electron. Reading it off the input (rather than adding a second
  # `github:NixOS/nixpkgs/<rev>` pin) keeps the Electron version locked to
  # whatever hermes-agent itself locked, so the two cannot drift apart.
  hermesPkgs = import "${inputs.hermes-agent.inputs.nixpkgs}" {
    inherit system;
    config.allowUnfree = true;
  };

  # Electron republished v43.5.1's headers tarball after hermes-agent pinned
  # its hash, so upstream `nix/desktop.nix` fails its fixed-output check:
  #
  #   error: hash mismatch in fixed-output derivation '...-headers.tar.gz.drv'
  #            specified: sha256-f8bSbLRmtbP93CJAvEBs+sHWDZ1xP2bcpLhC1EnOmZU=
  #                 got: sha256-+dR2pWvfSj1DUJXOr5BGlCHFv1FVxWOyHFGoliFcbXU=
  #
  # Override exactly that one fetchurl to the tarball's current content hash;
  # the rest of desktop.nix is used verbatim.
  #
  # The URL is derived from the Electron we actually build against, so if
  # hermes-agent ever bumps its nixpkgs (and with it Electron), the URL moves
  # with it and this build fails loudly on the now-stale hash below instead of
  # silently mismatching. Update it from the "got:" line in that failure.
  electronHeadersUrl = "https://artifacts.electronjs.org/headers/dist/v${hermesPkgs.electron.version}/node-v${hermesPkgs.electron.version}-headers.tar.gz";
  electronHeadersHash = "sha256-+dR2pWvfSj1DUJXOr5BGlCHFv1FVxWOyHFGoliFcbXU=";

  hermesPkgsPatched = hermesPkgs.extend (final: prev: {
    fetchurl =
      args:
      if (args.url or "") == electronHeadersUrl then
        prev.fetchurl (args // { sha256 = electronHeadersHash; })
      else
        prev.fetchurl args;
  });

  # Re-instantiate upstream `nix/desktop.nix` against the patched package set,
  # reusing the already-built agent package and the flake's npm build library.
  # `callPackage` keeps the result overridable, so the module's own
  # `extraEnv`/`extraRun` wiring still applies to it.
  hermesDesktop = hermesPkgsPatched.callPackage "${inputs.hermes-agent}/nix/desktop.nix" {
    pkgs = hermesPkgsPatched;
    inherit (hermesFull) hermesNpmLib;
    hermesAgent = hermesFull;
  };
in
{
  programs.hermes-agent = {
    enable = true;
    desktop = {
      enable = true;
      package = hermesDesktop;
    };
  };
}
