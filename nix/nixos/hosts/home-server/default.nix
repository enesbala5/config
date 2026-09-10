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
    ./modules/openhands-ui
  ];

  # Flip on after `manage-secret incus-ai-agent-secrets.age` and first apply.
  homeServer.incusAiAgent.enable = true;

  # Flip on after `manage-secret hermes-agent-secrets.age`.
  homeServer.incusHermesAgent.enable = false;
  # homeServer.incusHermesAgent.bridge.enable = true; # after hermes-bridge-secrets.age
  homeServer.openHandsUi.enable = false;
