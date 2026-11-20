{ config, lib, ... }:
{
  imports = [
    ./server
    ./remote
  ];

  options.modules.home.remoteRender.enable = lib.mkEnableOption "generic remote render jobs";

  config.assertions = [
    {
      assertion = !config.modules.home.remoteRender.server.enable || config.modules.home.remoteRender.enable;
      message = "modules.home.remoteRender.server.enable requires modules.home.remoteRender.enable";
    }
    {
      assertion = !config.modules.home.remoteRender.remote.enable || config.modules.home.remoteRender.enable;
      message = "modules.home.remoteRender.remote.enable requires modules.home.remoteRender.enable";
    }
  ];
}
