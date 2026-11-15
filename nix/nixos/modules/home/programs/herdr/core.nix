{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.herdr;
  packages = pkgs.callPackage ./packages.nix { };
in
{
  options.modules.home.herdr.core.enable =
    lib.mkEnableOption "Herdr core (headless terminals and the hc CLI)";

  config = lib.mkIf (cfg.enable && cfg.core.enable) {
    # hc starts and supervises herdr-core itself through transient systemd
    # units (hc-serve-*), so no service is declared here. The desktop app is a
    # separate client; this option is enough on a headless server.
    home.packages = [ packages.herdr-core ];
  };
}
