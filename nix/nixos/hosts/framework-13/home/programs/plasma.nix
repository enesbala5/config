{ inputs, ... }:
{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  programs.plasma = {
    enable = true;

    # Dolphin/KIO drop menu (Plasma 6.4+ / KF 6.14+): move on same device
    # instead of always asking Move/Copy/Link. Cross-device still prompts.
    # Key lives in kdeglobals [KDE], not dolphinrc.
    configFile."kdeglobals"."KDE"."DndBehavior" = "MoveIfSameDevice";

    # CANARY: absurd Places sidebar icons — if you don't see huge icons after
    # pkill dolphin && dolphin, plasma-manager / dolphinrc is not being read.
    # Remove once confirmed.
    configFile."dolphinrc"."PlacesPanel"."IconSize" = 256;
  };
}
