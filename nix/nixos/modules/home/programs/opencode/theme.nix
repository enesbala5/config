{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.home.opencode;
in
{
  config = lib.mkIf cfg.enable {
    programs.opencode.settings.theme = "github";
  };
}
