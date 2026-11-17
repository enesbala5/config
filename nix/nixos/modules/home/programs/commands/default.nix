{
  config,
  data,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.home.commands;

  commandType = lib.types.submodule {
    options = {
      script = lib.mkOption {
        type = lib.types.str;
        description = "Executable to exec. A repo path stays live across edits.";
      };

      runtimeInputs = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Packages prepended to PATH before exec.";
      };
    };
  };

  normalize =
    spec:
    if builtins.isString spec then
      {
        script = spec;
        runtimeInputs = [ ];
      }
    else
      spec;
in
{
  options.modules.home.commands = lib.mkOption {
    type = lib.types.attrsOf (lib.types.either lib.types.str commandType);
    default = { };
    description = "Commands on PATH that exec a live script.";
  };

  config = {
    modules.home.commands = {
      # Tailnet HTTPS previews, independent of Herdr/Ovis. Live repo source;
      # explicit runtime tools also work from agents with a minimal PATH.
      network-serve = {
        script = "${data.configDirectory}/scripts/utilities/network-serve";
        runtimeInputs = [
          pkgs.tailscale
          pkgs.nodejs
        ];
      };

      # One prompt, no harness, against the home-server model. Reads
      # ~/.agents/skills for --skill and refuses oversized prompts.
      ask-local = "${data.configDirectory}/scripts/utilities/ask-local";

      telegram-notify = "${data.configDirectory}/tools/telegram/notify.sh";
      fix-history = "${data.configDirectory}/tools/zsh/scripts/fix-history.sh";

      manage-sunshine = "${data.configDirectory}/scripts/utilities/manage-sunshine.sh";
      reload-hyprlock = "${data.configDirectory}/scripts/utilities/reload-hyprlock.sh";
      clear-monitor-config = "${data.configDirectory}/scripts/utilities/clear-monitor-lua.sh";
      toggle-polarity = "${data.configDirectory}/scripts/utilities/toggle-polarity.sh";
      toggle-dnd = "${data.configDirectory}/scripts/utilities/dnd-toggle.sh";

      acknowledge-smartd-error = "${data.configDirectory}/scripts/hosts/home-server/smartd/acknowledge-error.sh";
      stu-rclone = "${data.configDirectory}/scripts/utilities/stu-rclone.sh";
      nixos-rebuild-switch = "${data.configDirectory}/scripts/rebuild-switch.sh";
      soft-shutdown = "${data.configDirectory}/scripts/power/shutdown.sh";
      soft-reboot = "${data.configDirectory}/scripts/power/reboot.sh";
      stt = "${data.configDirectory}/scripts/audio/handy-bt-toggle.sh";
      tts = "${data.configDirectory}/scripts/audio/hypr-piper-speak.sh";
    };

    home.packages = lib.mapAttrsToList (
      name: spec:
      let
        command = normalize spec;
      in
      pkgs.writeShellScriptBin name ''
        ${lib.optionalString (command.runtimeInputs != [ ]) ''
          export PATH="${lib.makeBinPath command.runtimeInputs}:$PATH"
        ''}
        exec ${lib.escapeShellArg command.script} "$@"
      ''
    ) cfg;
  };
}
