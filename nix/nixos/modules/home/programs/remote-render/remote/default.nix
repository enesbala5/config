{ config, lib, pkgs, ... }:
let
  cfg = config.modules.home.remoteRender.remote;
  cli = pkgs.writeShellApplication {
    name = "render-remote";
    runtimeInputs = [
      pkgs.openssh
      pkgs.rsync
      pkgs.jq
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      export RENDER_REMOTE_HOST=${lib.escapeShellArg cfg.host}
      export RENDER_REMOTE_ROOT=${lib.escapeShellArg cfg.remoteRoot}
      ${builtins.readFile ./render-remote.sh}
    '';
  };
in
{
  options.modules.home.remoteRender.remote = {
    enable = lib.mkEnableOption "render-remote, the client for running render jobs on the render host";

    host = lib.mkOption {
      type = lib.types.str;
      default = "home-server";
      description = "ssh host with render-worker, Blender and FFmpeg (see remoteRender.server).";
    };

    remoteRoot = lib.mkOption {
      type = lib.types.str;
      default = "render-jobs";
      description = "Job directory on the host; relative paths are under its home directory.";
    };
  };

  config = lib.mkIf (config.modules.home.remoteRender.enable && cfg.enable) {
    home.packages = [ cli ];
  };
}
