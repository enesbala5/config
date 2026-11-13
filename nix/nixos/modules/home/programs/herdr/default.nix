{
  config,
  lib,
  pkgs,
  inputs,
  data,
  system,
  ...
}:
let
  cfg = config.modules.home.herdr;
  # Latest Herdr release. Hydra has this build; the herdr flake tracks
  # master past the tag and is not in a binary cache.
  herdrPkg = inputs.nixpkgs-herdr.legacyPackages.${system}.herdr;
in
{
  imports = [
    ./fonts.nix
    ./plugins.nix
    ./desktop.nix
    ./gpui.nix
    ./mobile.nix
  ];

  options.modules.home.herdr.enable = lib.mkEnableOption "Herdr";

  config = lib.mkIf cfg.enable {
    home.packages = [
      herdrPkg
      # Auto Title's `herdr plugin install` builds a Go plugin on the machine.
      pkgs.go
      # Agent Head's startup hook runs head.js.
      pkgs.nodejs
    ];

    # Herdr has no home-manager module for its config. Only these files are
    # symlinked; the rest of each directory is runtime state and stays writable.
    # This is the TUI's config. herdr-core reads ~/.config/herdr-core/config.toml.
    home.file = {
      ".config/herdr/config.toml" = {
        source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/config.toml";
      };

      ".config/herdr-auto-title/config.env" = {
        source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/plugins/auto-title/config.env";
      };

      ".config/herdr/plugins/config/herdr-bar/config.json" = {
        source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/plugins/herdr-bar/config.json";
      };
    };
  };
}
