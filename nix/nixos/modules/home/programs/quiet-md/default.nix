{
  config,
  lib,
  inputs,
  system,
  ...
}:
let
  cfg = config.modules.home.quietMd;
in
{
  options.modules.home.quietMd.enable = lib.mkEnableOption "Quiet.md";

  config = lib.mkIf cfg.enable {
    # Packaged in the quiet-md-nix submodule (github:enesbala5/quiet-md-nix):
    # it extracts upstream's prebuilt AppImage at build time, so nothing is
    # compiled here. See that repo for the wrapper and bump instructions.
    home.packages = [ inputs.quiet-md-nix.packages.${system}.default ];
  };
}
