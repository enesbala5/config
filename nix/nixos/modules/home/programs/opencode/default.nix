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

    # Stylix generates a "stylix" theme (base16 palette) and sets
    # settings.theme = "stylix" in config.json. The TUI picks its active theme
    # from tui.json instead, where "github" stays the default (see tui.nix), so
    # stylix's theme is available via /theme without changing the default.
    stylix.targets.opencode.enable = true;
  };
}
