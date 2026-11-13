{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.herdr;

  # Herdr Agent Icons Max (herdr-radar, MIT). Family name is "Herdr Agent Icons Max".
  # Pin a commit: the file on `main` is not hash-stable.
  # Cmap at this commit is U+E1A0–U+E1BA and U+E1C0–U+E1C5.
  herdrAgentIcons = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/hhdebb/herdr-radar/47c022d4fcfe115e9e45433aa953510a41349111/dist/HerdrAgentIconsMax-Regular.ttf";
    hash = "sha256-G4GZSWsiPQdh/DpJ1bJRC9o43quCyzdYvzmASVvwUnI=";
  };
in
{
  config = lib.mkIf cfg.enable {
    # NixOS fontconfig already scans $XDG_DATA_HOME/fonts (~/.local/share/fonts).
    xdg.dataFile."fonts/HerdrAgentIconsMax-Regular.ttf".source = herdrAgentIcons;

    # Kitty does not pick a private-use font up as a fallback family.
    programs.kitty.settings.symbol_map = "U+E1A0-U+E1BA,U+E1C0-U+E1C5 Herdr Agent Icons Max";
  };
}
