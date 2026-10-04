{
  config,
  lib,
  data,
  ...
}:

let
  cfg = config.modules.home.opencode;
in
{
  config = lib.mkIf cfg.enable {
    # MCP servers contain no secrets: remote auth is stored by opencode in
    # ~/.local/share/opencode/mcp-auth.json, so this block is safe to manage.
    programs.opencode.settings.mcp = {
      Polar = {
        type = "remote";
        url = "https://mcp.polar.sh/mcp/polar-mcp";
        enabled = true;
      };

      axiom = {
        type = "remote";
        url = "https://mcp.axiom.co/mcp";
        headers = { };
        enabled = true;
      };

      playwright = {
        type = "local";
        command = [ "${data.configDirectory}/scripts/browser/playwright-mcp.sh" ];
        enabled = true;
      };

      openseo = {
        type = "remote";
        url = "https://openseo.enesbala.com/mcp";
        enabled = true;
      };
    };
  };
}
