{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (config.lib.stylix) colors;

  # Stylix names its generated KDE color scheme after the base16 scheme, with
  # non-alphanumerics stripped (e.g. "Google Light" -> "GoogleLight"). This
  # matches the file name Stylix itself writes.
  schemeSlug = lib.concatStrings (lib.filter lib.isString (builtins.split "[^a-zA-Z]" colors.scheme));

  rgb = name: "${colors."${name}-rgb-r"},${colors."${name}-rgb-g"},${colors."${name}-rgb-b"}";

  # Mirrors Stylix's KDE palette mapping (modules/kde/hm.nix) so KDE apps read
  # the same colors instead of falling back to Breeze.
  viewColors = {
    BackgroundNormal = rgb "base00";
    BackgroundAlternate = rgb "base01";
    DecorationFocus = rgb "base0D";
    DecorationHover = rgb "base0D";
    ForegroundNormal = rgb "base05";
    ForegroundActive = rgb "base05";
    ForegroundInactive = rgb "base05";
    ForegroundLink = rgb "base05";
    ForegroundVisited = rgb "base05";
    ForegroundNegative = rgb "base08";
    ForegroundNeutral = rgb "base0D";
    ForegroundPositive = rgb "base0B";
  };

  colorEffects = {
    ColorEffect = 0;
    ColorAmount = 0;
    ContrastEffect = 1;
    ContrastAmount = "0.5";
    IntensityEffect = 0;
    IntensityAmount = 0;
  };

  colorscheme = {
    General = {
      ColorScheme = schemeSlug;
      Name = colors.scheme;
    };

    "ColorEffects:Disabled" = colorEffects;
    "ColorEffects:Inactive" = colorEffects;

    "Colors:Window" = viewColors;
    "Colors:View" = viewColors;
    "Colors:Button" = viewColors;
    "Colors:Tooltip" = viewColors;
    "Colors:Complementary" = viewColors;
    "Colors:Selection" = viewColors // {
      BackgroundNormal = rgb "base0D";
      BackgroundAlternate = rgb "base0D";
      ForegroundNormal = rgb "base00";
      ForegroundActive = rgb "base00";
      ForegroundInactive = rgb "base00";
      ForegroundLink = rgb "base00";
      ForegroundVisited = rgb "base00";
    };
  };
in
{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  programs.plasma = {
    enable = true;

    # Official Plasma 6.4+ / KF 6.14+ setting (System Settings → Workspace
    # Behavior → Drag and Drop). KIO DropJob reads this on each drop.
    # Same device → move without menu; Shift → show menu; other device → ask.
    configFile."kdeglobals"."KDE"."DndBehavior" = "MoveIfSameDevice";

    # Also on dolphinrc: DropJob uses KSharedConfig::openConfig() (app rc +
    # kdeglobals cascade). Writing both removes cascade ambiguity.
    configFile."dolphinrc"."KDE"."DndBehavior" = "MoveIfSameDevice";

    # Stylix ships its KDE color scheme through a system-level XDG_CONFIG_DIRS
    # entry. Sessions launched directly by the display manager (GDM → Hyprland)
    # don't import that entry, so KDE apps like Dolphin never see it and fall
    # back to the default Breeze palette, which clashes with the Stylix/Kvantum
    # palette used by the rest of Qt. Writing the scheme into the user's own
    # config/data dirs makes it polarity-aware and independent of the session
    # environment, and plasma-manager rewrites it on every activation (so it
    # follows the Stylix specialisation switch).
    configFile."kdeglobals"."UiSettings"."ColorScheme" = schemeSlug;
    dataFile."color-schemes/${schemeSlug}.colors" = colorscheme;
  };
}
