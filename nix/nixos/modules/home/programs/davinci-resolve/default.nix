{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.davinciResolve;
in
{
  options.modules.home.davinciResolve = {
    enable = lib.mkEnableOption "DaVinci Resolve";

    package = lib.mkOption {
      type = lib.types.package;
      # nixpkgs 26.05 pins 20.3.2. It is unfree and bubblewrap/FHS-wrapped, so
      # the wrapper carries its own runtime deps. allowUnfree is set globally
      # in the flake's pkgs import.
      default = pkgs.davinci-resolve;
      defaultText = lib.literalExpression "pkgs.davinci-resolve";
      description = "DaVinci Resolve package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The nixpkgs package ships bin/davinci-resolve plus an XDG desktop entry
    # and icons, so home-manager registers the launcher automatically.
    home.packages = [ cfg.package ];
  };
}
