{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.home.codex;

  # Import every sibling module (catalog.nix, wrapper.nix, …) so a new config
  # area can be added by dropping a .nix file into this directory.
  dir = ./.;

  siblingModules = map (name: dir + "/${name}") (
    builtins.filter (name: name != "default.nix" && builtins.match ".*\\.nix" name != null) (
      builtins.attrNames (builtins.readDir dir)
    )
  );
in
{
  imports = siblingModules;

  options.modules.home.codex.enable = lib.mkEnableOption "Codex CLI";

  config = lib.mkIf cfg.enable {
    programs.codex.enable = true;
  };
}
