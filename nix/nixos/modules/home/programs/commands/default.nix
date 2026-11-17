{
  config,
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
    # Values are set by the shared home module and each host's home config.
    # attrsOf merges those sets by name.
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
