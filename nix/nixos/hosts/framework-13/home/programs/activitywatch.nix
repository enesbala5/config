{
  pkgs,
  inputs,
  system,
  ...
}:
{
  services.activitywatch = {
    enable = true;
    package = pkgs.aw-server-rust;

    watchers = {
      aw-watcher-afk = {
        package = pkgs.aw-watcher-afk;

        settings = {
          poll_time = 1000;
        };
      };

      aw-watcher-window = {
        package = pkgs.activitywatch;

        settings = {
          poll_time = 1000;
          exclude_title = true;
        };
      };

      aw-watcher-window-hyprland = {
        package = inputs.aw-watcher-window-hyprland.defaultPackage.${system};
      };
    };
  };
}
