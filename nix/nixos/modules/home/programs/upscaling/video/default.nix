{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.upscaling.video;
  python = pkgs.python3.withPackages (ps: [ ps.pillow ]);
  cli = pkgs.writeShellApplication {
    name = "upscale-video";
    runtimeInputs = [
      python
      cfg.ffmpegPackage
      cfg.package
    ];
    text = ''
      export UPSCALE_VIDEO_MODELS=${lib.escapeShellArg "${cfg.package}/share/models"}
      export UPSCALE_VIDEO_TILE=${toString cfg.tileSize}
      export UPSCALE_VIDEO_GPU=${toString cfg.gpu}
      export UPSCALE_VIDEO_CHUNK=${toString cfg.chunkSize}
      export UPSCALE_VIDEO_CRF=${toString cfg.crf}
      ${lib.optionalString (cfg.scratchDirectory != null) ''
        export UPSCALE_VIDEO_SCRATCH=${lib.escapeShellArg cfg.scratchDirectory}
      ''}
      exec ${python}/bin/python3 ${./upscale-video.py} "$@"
    '';
  };
in
{
  options.modules.home.upscaling.video = {
    enable = lib.mkEnableOption "offline SDR video upscaling with Real-ESRGAN and Vulkan";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.realesrgan-ncnn-vulkan;
      defaultText = lib.literalExpression "pkgs.realesrgan-ncnn-vulkan";
      description = "NCNN/Vulkan executable and models in share/models. No ROCm required.";
    };
    ffmpegPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ffmpeg;
      defaultText = lib.literalExpression "pkgs.ffmpeg";
      description = "FFmpeg package supplying ffmpeg and ffprobe with libx264 support.";
    };
    tileSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 128;
      description = "Model tile size in pixels; conservative starting point, not an RX 570 benchmark.";
    };
    gpu = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = "NCNN Vulkan GPU index (not necessarily the DRM card index).";
    };
    chunkSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = "Maximum source frames staged with their upscaled PNGs at once.";
    };
    crf = lib.mkOption {
      type = lib.types.ints.between 0 51;
      default = 18;
      description = "H.264 constant rate factor; lower means higher quality/larger files.";
    };
    scratchDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Disk-backed scratch parent. Null uses XDG_CACHE_HOME/upscaling (not /tmp).";
    };
  };

  config = lib.mkIf (config.modules.home.upscaling.enable && cfg.enable) {
    home.packages = [
      cli
      pkgs.vulkan-tools
    ];
  };
}
