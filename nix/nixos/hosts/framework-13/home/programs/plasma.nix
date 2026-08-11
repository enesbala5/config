{ inputs, ... }:
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
  };
}
