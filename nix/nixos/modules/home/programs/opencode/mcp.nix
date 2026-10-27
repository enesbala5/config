{
  config,
  lib,
  data,
  ...
}:

let
  cfg = config.modules.home.opencode;

  # Single source of truth shared with Cursor, Zed and pi.
  # Edit ~/config/misc/mcp/mcp.json, then run scripts/utilities/mcp-sync.mjs.
  canonical = builtins.fromJSON (builtins.readFile "${data.configDirectory}/misc/mcp/mcp.json");

  # ${VAR} in mcp.json becomes OpenCode's {env:VAR}. wrapper.nix exports
  # osConfig.age.secrets."mcp-secrets.json" at launch, so the token never enters the Nix store.
  substEnv =
    s:
    let
      parts = builtins.split "[$][{]([A-Za-z_][A-Za-z0-9_]*)[}]" s;
    in
    lib.concatMapStrings (
      part: if builtins.isList part then "{env:${builtins.head part}}" else part
    ) parts;

  mapStrings = lib.mapAttrs (_: substEnv);

  toOpencode =
    server:
    if server ? command then
      {
        type = "local";
        command = [ server.command ] ++ (server.args or [ ]);
        enabled = true;
      }
      // lib.optionalAttrs (server ? env && server.env != { }) { environment = mapStrings server.env; }
    else
      {
        type = "remote";
        url = substEnv server.url;
        enabled = true;
      }
      // lib.optionalAttrs (server ? headers && server.headers != { }) {
        headers = mapStrings server.headers;
        oauth = false;
      };

  servers = lib.filterAttrs (_: server: server.enabled or true) canonical.mcpServers;
in
{
  config = lib.mkIf cfg.enable {
    programs.opencode.settings.mcp = lib.mapAttrs (_: toOpencode) servers;
  };
}
