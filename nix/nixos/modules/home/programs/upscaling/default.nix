{ config, lib, ... }:
{
  imports = [
    ./video
    ./remote
  ];

  options.modules.home.upscaling.enable = lib.mkEnableOption "local media upscaling tools";

  config.assertions = [
    {
      assertion = !config.modules.home.upscaling.video.enable || config.modules.home.upscaling.enable;
      message = "modules.home.upscaling.video.enable requires modules.home.upscaling.enable";
    }
    {
      assertion = !config.modules.home.upscaling.remote.enable || config.modules.home.upscaling.enable;
      message = "modules.home.upscaling.remote.enable requires modules.home.upscaling.enable";
    }
  ];
}
