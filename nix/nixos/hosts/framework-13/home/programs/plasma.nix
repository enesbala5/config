{ inputs, ... }:
{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  programs.plasma = {
    enable = true;

    # Only write declared keys; leave the rest of dolphinrc alone.
    configFile."dolphinrc"."General"."DragAndDropAction" = 4;
  };
}
