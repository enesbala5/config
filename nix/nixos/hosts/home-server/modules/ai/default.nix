{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.homeServer.ai;

  llamaPackage =
    if unstable ? llama-cpp-vulkan then
      unstable.llama-cpp-vulkan
    else
      unstable.llama-cpp.override { vulkanSupport = true; };

  activeModel = cfg.models.available.${cfg.model} or {
    displayName = cfg.model;
    file = "${cfg.model}.gguf";
    url = "";
  };

  modelPath = "${cfg.models.directory}/${activeModel.file}";
in
{
  imports = [ ./models ];

  options.homeServer.ai = {
    enable = lib.mkEnableOption "local llama.cpp inference with Vulkan (Polaris / RX 570)";

    package = lib.mkOption {
      type = lib.types.package;
      default = llamaPackage;
      description = "llama.cpp build. Defaults to unstable + Vulkan; ROCm is a dead end on Polaris.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = ''
        Listen address. 0.0.0.0 lets Incus guests reach the host via incusbr0
        (already a trusted interface). LAN access still needs openFirewall.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "llama-server port (OpenAI-compatible /v1).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the listen port on the host firewall for LAN clients.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen";
      description = "Catalog key to serve (qwen, mistral, deepseek). Single process — 25.11 llama-server takes one -m.";
    };

    contextSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4096;
      description = "Context window. 4K keeps Qwen3-4B Q4 in the 4 GB VRAM working set; 8K starts leaning on GTT.";
    };

    gpuLayers = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 99;
      description = "Layers to offload. 99 = all layers the backend can place on the GPU.";
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional llama-server flags appended after the Polaris defaults.";
    };

    gttSizeMiB = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 8192;
      description = "amdgpu.gttsize kernel parameter (MiB). Null leaves the driver default.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.models.available ? ${cfg.model};
        message = "homeServer.ai.model \"${cfg.model}\" is missing from homeServer.ai.models.available";
      }
    ];

    # Mesa RADV is the only GPU compute path that still works on Polaris.
    hardware.graphics.enable = true;

    boot.kernelParams = lib.mkIf (cfg.gttSizeMiB != null) [
      "amdgpu.gttsize=${toString cfg.gttSizeMiB}"
    ];

    environment.systemPackages = with pkgs; [
      amdgpu_top
      radeontop
      clinfo
      vulkan-tools
      cfg.package
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.models.directory} 0755 root root -"
    ];

    # Fetch the selected GGUF once. Keeping weights out of the Nix store
    # avoids pinning a multi-gigabyte blob in every generation.
    systemd.services.llama-cpp-model = {
      description = "Download ${activeModel.displayName} GGUF";
      wantedBy = [ "multi-user.target" ];
      before = [ "llama-cpp.service" ];
      requiredBy = [ "llama-cpp.service" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -euo pipefail
        dest="${modelPath}"
        mkdir -p "${cfg.models.directory}"
        if [ -f "$dest" ]; then
          echo "model already present: $dest"
          exit 0
        fi
        tmp="$dest.partial"
        ${pkgs.curl}/bin/curl -fL --retry 5 --retry-delay 2 \
          -o "$tmp" "${activeModel.url}"
        mv "$tmp" "$dest"
        chmod 0644 "$dest"
      '';
    };

    services.llama-cpp = {
      enable = true;
      package = cfg.package;
      host = cfg.host;
      port = cfg.port;
      model = modelPath;
      openFirewall = cfg.openFirewall;
      extraFlags = [
        "-ngl"
        (toString cfg.gpuLayers)
        "-c"
        (toString cfg.contextSize)
        "-fa"
        "on"
        "--no-mmap"
      ]
      ++ cfg.extraFlags;
    };

    # DynamicUser + ProtectSystem=strict cannot write ~/.cache; RADV
    # then disables the shader cache and the unit can fail on first start.
    systemd.services.llama-cpp = {
      after = [ "llama-cpp-model.service" ];
      requires = [ "llama-cpp-model.service" ];
      environment = {
        XDG_CACHE_HOME = "/var/cache/llama-cpp";
        MESA_SHADER_CACHE_DIR = "/var/cache/llama-cpp";
      };
      serviceConfig = {
        CacheDirectory = "llama-cpp";
        ReadWritePaths = [
          cfg.models.directory
          "/var/cache/llama-cpp"
        ];
      };
    };
  };
}
