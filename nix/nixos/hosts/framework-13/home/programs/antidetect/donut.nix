# Donut Browser via the upstream flake's release-start app.
# Profiles, cookies, and proxy assignment stay inside Donut.
# Agenix secret is available at runtime for future import scripts (PENDING).
{
  pkgs,
  lib,
  inputs,
  system,
  config,
  ...
}:
let
  # The upstream flake exposes only an app, not a package. Wrap the launcher
  # so it lands on PATH and can be used from desktop entries.
  donut = pkgs.writeShellScriptBin "donut" ''
    exec ${inputs.donutbrowser.apps.${system}.release-start.program} "$@"
  '';
in
{
  home.packages = [ donut ];

  xdg.desktopEntries.donut = {
    name = "Donut Browser";
    genericName = "Anti-Detect Browser";
    comment = "Open-source anti-detect browser with unlimited profiles";
    icon = "donut"; # falls back; Donut ships its own on first run
    exec = "${lib.getExe donut} %U";
    type = "Application";
    terminal = false;
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeType = [
      "text/html"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
  };

  # PENDING: bulk proxy import script that reads
  # ${config.age.secrets."proxies-us".path}
  # and feeds Donut's local API / import format.
  # Donut exposes a local API on the free tier.
}
