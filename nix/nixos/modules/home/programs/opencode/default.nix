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

  options.modules.home.opencode.enable = lib.mkEnableOption "OpenCode";

  config = lib.mkIf cfg.enable {
    programs.opencode.enable = true;

    # Stylix generates a "stylix" theme and sets tui.theme to it.
    # tui.nix forces "github", so the stylix theme stays available via /theme.
    stylix.targets.opencode.enable = true;
  };
}
