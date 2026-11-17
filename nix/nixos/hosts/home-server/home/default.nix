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

  modules.home.commands = [
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
}
