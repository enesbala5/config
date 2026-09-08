# ActivityWatch

#	- [x] Key Modules
#	  - [x] bobvanderlinden/aw-watcher-window-hyprland
#	  - [x] aw-watcher-web // Chromium & Firefox
#	  - [x] sachk/aw-watcher-zed // Zed Editor
#	  - [x] aw-watcher-vscode // VS Code & Cursor
#	  - [ ] LordGrimmauld/aw-watcher-obsidian // Obsidian

#	- [ ] Optional
#	  - [ ] Alwinator/aw-watcher-utilization // Monitors CPU, RAM, disk, network, and sensor usage
#	  - [ ] RTnhN/aw-watcher-toggl // A Watcher to import time entries from Toggl.

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
