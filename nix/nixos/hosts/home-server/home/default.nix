{
  inputs,
  pkgs,
  config,
  data,
  ...
}:
{
  imports = [
    ./programs

    ../../../modules/home/programs/opencode
  ];

  # DaVinci Resolve moved here from framework-13 (this is the GPU host).
  modules.home.davinciResolve.enable = true;

  modules.home.commands = [
    {
      prefix = "${data.configDirectory}/scripts/utilities";
      entries.manage-sunshine = "manage-sunshine.sh";
    }
    {
      prefix = "${data.configDirectory}/scripts/hosts/home-server/smartd";
      entries.acknowledge-smartd-error = "acknowledge-error.sh";
    }
  ];

  modules.home.herdr.enable = true;
  modules.home.herdr.core.enable = true;
  modules.home.dsh.enable = false;

  modules.home.upscaling = {
    enable = true;
    video.enable = true;
  };

  # render-worker for delegating Blender composition renders from framework-13.
  modules.home.remoteRender = {
    enable = true;
    server.enable = true;
  };
}
