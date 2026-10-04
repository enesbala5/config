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
}
