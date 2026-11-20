{ config, lib, pkgs, ... }:
let
  cfg = config.modules.home.remoteRender.server;
  worker = pkgs.writeShellScriptBin "render-worker" ''
    export PATH="${lib.makeBinPath [
      pkgs.bash
      pkgs.coreutils
      pkgs.findutils
      pkgs.jq
      pkgs.gnused
    ]}:$PATH"
    export RENDER_WORKER_POLL=${toString cfg.poll}
    ${builtins.readFile ./render-worker.sh}
  '';
in
{
  options.modules.home.remoteRender.server = {
    enable = lib.mkEnableOption "render-worker, the job runner on the render host";

    poll = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Seconds between status.json progress updates.";
    };

    blenderPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.blender;
      defaultText = lib.literalExpression "pkgs.blender";
      description = ''
        Blender available to render jobs. The locked nixpkgs provides 5.1.1;
        override only when a composition needs a different version.
      '';
    };
  };

  config = lib.mkIf (config.modules.home.remoteRender.enable && cfg.enable) {
    home.packages = [
      worker
      cfg.blenderPackage
      pkgs.ffmpeg
      pkgs.jq
      pkgs.xvfb-run
      pkgs.xorg.xauth
    ];
  };
}
