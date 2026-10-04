{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.home.opencode;

  tuiFormat = pkgs.formats.json { };
in
{
  # OpenCode 1.17+ reads TUI settings (theme, attention sounds, …) from a
  # dedicated tui.json, separate from the server config the home-manager module
  # writes to config.json. The legacy theme/keybinds keys in config.json are
  # deprecated and migrated away, so theme lives here now.
  #
  # attention.enabled is off by default; turning it on plays the built-in sound
  # pack (and fires desktop notifications when the terminal is blurred) for
  # questions, permissions, errors, completed sessions, and finished subagents.
  config = lib.mkIf cfg.enable {
    xdg.configFile."opencode/tui.json".source = tuiFormat.generate "opencode-tui.json" {
      "$schema" = "https://opencode.ai/tui.json";

      theme = "github";

      attention = {
        enabled = true;
        sound = true;
        volume = 0.4;
      };
    };
  };
}
