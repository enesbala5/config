# hypruse: computer use for Hyprland over MCP (issue #108).
#
# Upstream Home Manager module installs the package and, when Home Manager
# has programs.mcp, registers a servers.hypruse entry. This repo's clients
# still read misc/mcp/mcp.json via mcp-sync, so that file is the client SSOT.
{
  inputs,
  system,
  ...
}:
{
  imports = [ inputs.hypruse.homeModules.default ];

  programs.hypruse = {
    enable = true;
    # Upstream flake src omits uv.lock; one unit test still opens it (0.15.0).
    package = inputs.hypruse.packages.${system}.hypruse.overrideAttrs (_: {
      disabledTests = [ "test_claude_plugin_runs_its_own_locked_source" ];
    });
    # Optional later: env.HYPRUSE_BACKGROUND = "1"; for agent-owned workspaces.
  };
}
