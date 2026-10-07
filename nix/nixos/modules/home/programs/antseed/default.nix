{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.home.antseed;
in
{
  options.modules.home.antseed.enable = lib.mkEnableOption "Antseed buyer proxy";

  config = lib.mkIf cfg.enable {
    # Antseed buyer proxy: local OpenAI/Anthropic-compatible endpoint on
    # 127.0.0.1:8377 that routes through the Antseed P2P network. Loopback
    # only. Chain/identity/config live under ~/.antseed (identity.key must
    # never move off this host).
    systemd.user.services.antseed-buyer = {
      Unit = {
        Description = "Antseed Buyer Proxy";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Install.WantedBy = [ "default.target" ];

      Service = {
        ExecStart = "${inputs.antseed.packages.${pkgs.system}.default}/bin/antseed buyer start";
        Restart = "on-failure";
        RestartSec = 10;
      };
    };
  };
}
