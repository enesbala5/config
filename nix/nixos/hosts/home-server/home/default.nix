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

  modules.home.herdr.enable = true;
  modules.home.dsh.enable = false;
}
