{
  config,
  lib,
  ...
}:

let
  cfg = config.modules.home.opencode;
in
{
  # Home-manager writes this to ~/.config/opencode/tui.json. Writing that
  # file ourselves conflicts with programs.opencode.tui on 26.05.
  #
  # attention.enabled is off by default; turning it on plays the built-in sound
  # pack (and fires desktop notifications when the terminal is blurred) for
  # questions, permissions, errors, completed sessions, and finished subagents.
  config = lib.mkIf cfg.enable {
    programs.opencode.tui = {
      # Stylix 26.05 also sets this to "stylix". Keep github as the active theme.
      theme = lib.mkForce "github";

      attention = {
        enabled = true;
        sound = true;
        volume = 0.4;
      };
    };
  };
}
