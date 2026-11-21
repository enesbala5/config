{
  config,
  lib,
  inputs,
  system,
  ...
}:
let
  cfg = config.modules.home.claudeDesktop;
in
{
  options.modules.home.claudeDesktop = {
    enable = lib.mkEnableOption "Claude Desktop";

    fhs = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Use the FHS-wrapped build from claude-desktop-linux-flake. It bundles
        docker, nodejs and uv so MCP servers configured in Claude Desktop can
        run npx/uvx/docker subprocesses, which the plain Electron wrapper
        cannot find on NixOS. Enable this if you use MCP servers.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (if cfg.fhs then
        inputs.claude-desktop.packages.${system}.claude-desktop-with-fhs
      else
        inputs.claude-desktop.packages.${system}.claude-desktop)
    ];
  };
}
