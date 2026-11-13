{
  config,
  lib,
  inputs,
  system,
  ...
}:
let
  cfg = config.modules.home.herdr;
in
{
  options.modules.home.herdr.gpui = lib.mkEnableOption "Herdr GPUI desktop client";

  config = lib.mkIf (cfg.enable && cfg.gpui) {
    home.packages = [ inputs.herdr-gpui.packages.${system}.default ];
  };
}
