# Shared antidetect browsers for framework-13 only.
# Browsers manage their own profiles; Nix owns secrets, install, and desktop entries.
# Proxy import scripts are PENDING.
{
  lib,
  config,
  ...
}:
{
  imports = [
    ./donut.nix
    ./aliasmode.nix
  ];

  # Make the decrypted proxy list available at runtime (not in the store).
  # Future import helpers will read this path.
  home.sessionVariables.PROXIES_US = config.age.secrets."proxies-us".path;

  # Optional independent toggles (enabled by default so both can be compared).
  # programs.donut.enable = true;
  # programs.aliasmode.enable = true;
}
