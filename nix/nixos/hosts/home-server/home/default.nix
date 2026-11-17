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

  modules.home.commands.acknowledge-smartd-error = "${data.configDirectory}/scripts/hosts/home-server/smartd/acknowledge-error.sh";

  modules.home.herdr.enable = true;
  modules.home.herdr.core.enable = true;
  modules.home.dsh.enable = false;

  modules.home.upscaling = {
    enable = true;
    video.enable = true;
  };
}
