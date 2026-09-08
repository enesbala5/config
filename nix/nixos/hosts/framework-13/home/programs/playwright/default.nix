# Playwright on NixOS: packaged browsers + CDP into Helium (preferred) or Chrome.
{
  pkgs,
  lib,
  inputs,
  system,
  data,
  ...
}:
let
  helium = inputs.helium-browser.packages.${system}.default;
  cdpEndpoint = "http://127.0.0.1:9222";
in
{
  home.packages = [
    pkgs.nodejs
    pkgs.playwright-driver.browsers
    pkgs.curl
    (pkgs.writeShellScriptBin "helium-cdp" ''
      export HELIUM_BIN="${lib.getExe helium}"
      exec ${data.configDirectory}/scripts/browser/helium-cdp.sh "$@"
    '')
    (pkgs.writeShellApplication {
      name = "playwright-mcp";
      runtimeInputs = [ pkgs.nodejs ];
      text = ''
        exec npx -y @playwright/mcp@latest --cdp-endpoint=${cdpEndpoint} "$@"
      '';
    })
  ];

  home.sessionVariables = {
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "1";
    PLAYWRIGHT_MCP_CDP_ENDPOINT = cdpEndpoint;
    PLAYWRIGHT_MCP_EXECUTABLE_PATH = lib.getExe helium;
  };
}
