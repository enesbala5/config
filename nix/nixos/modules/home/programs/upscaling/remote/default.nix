{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.upscaling.remote;
  cli = pkgs.writeShellApplication {
    name = "upscale-remote";
    runtimeInputs = [
      pkgs.openssh
      pkgs.rsync
      pkgs.jq
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      export UPSCALE_REMOTE_HOST=${lib.escapeShellArg cfg.host}
      export UPSCALE_REMOTE_ROOT=${lib.escapeShellArg cfg.remoteRoot}
      ${builtins.readFile ./upscale-remote.sh}
    '';
  };
in
{
  options.modules.home.upscaling.remote = {
    enable = lib.mkEnableOption "upscale-remote, the client for upscaling on the GPU host";
    host = lib.mkOption {
      type = lib.types.str;
      default = "home-server";
      description = "ssh host that has upscale-video and gpu-lease (see upscaling.video).";
    };
    remoteRoot = lib.mkOption {
      type = lib.types.str;
      default = "upscale-jobs";
      description = "Job directory on the host; relative paths are under its home directory.";
    };
  };

  config = lib.mkIf (config.modules.home.upscaling.enable && cfg.enable) {
    home.packages = [ cli ];
  };
}
