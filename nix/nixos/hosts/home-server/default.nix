{
  config,
  pkgs,
  unstable,
  data,
  inputs,
  system,
  hostname,
  ...
}:
let
in
{
  imports = [
    ./modules/garage
    ./modules/disks/smartd.nix
    ./modules/power/ups.nix
    ./modules/backups
    ./modules/incus-ai-agent
    ./modules/incus-hermes-agent
    ./modules/caddy
  ];

  # Enable VMs for OpenHands AI and Hermes agents
  homeServer.incusAiAgent.enable = true;
  homeServer.incusHermesAgent.enable = true;
  homeServer.caddy.enable = true;
