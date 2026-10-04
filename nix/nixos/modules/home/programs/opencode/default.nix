{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.home.opencode;

  # Import every sibling module (theme.nix, mcp.nix, providers.nix, …) so a new
  # config area can be added by dropping a .nix file into this directory.
  dir = ./.;

  siblingModules = map (name: dir + "/${name}") (
    builtins.filter (name: name != "default.nix" && builtins.match ".*\\.nix" name != null) (
      builtins.attrNames (builtins.readDir dir)
    )
  );
in
{
  imports = siblingModules;

  options.modules.home.opencode.enable = lib.mkEnableOption "OpenCode CLI with the GitHub theme";

  config = lib.mkIf cfg.enable {
    programs.opencode.enable = true;

    # Stylix auto-themes opencode (settings.theme = "stylix"); this module owns
    # the theme instead, so opt out to avoid a conflicting definition.
    stylix.targets.opencode.enable = false;
  };
}
