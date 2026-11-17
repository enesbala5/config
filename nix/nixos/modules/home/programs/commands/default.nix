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
        description = "Script filename relative to the group's prefix.";
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

  # Shared home and each host append groups. prefix is always a directory;
  # the command name is the entry key.
  commands = lib.foldl' (
    defined: group:
    lib.foldl' (
      defined: name:
      if defined ? ${name} then
        throw "modules.home.commands: duplicate command '${name}'"
      else
        let
          command = normalize group.entries.${name};
        in
        defined
        // {
          ${name} = command // {
            script = "${group.prefix}/${command.script}";
          };
        }
    ) defined (lib.attrNames group.entries)
  ) { } cfg;
in
{
  options.modules.home.commands = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          prefix = lib.mkOption {
            type = lib.types.str;
            description = "Directory prepended to each entry's script.";
          };

          entries = lib.mkOption {
            type = lib.types.attrsOf (lib.types.either lib.types.str commandType);
            description = "Command name to a script filename, or to { script, runtimeInputs }.";
          };
        };
      }
    );
    default = [ ];
    description = "Commands on PATH that exec a live script. Host lists are concatenated onto the shared list.";
  };

  config = {
    home.packages = lib.mapAttrsToList (
      name: command:
      pkgs.writeShellScriptBin name ''
        ${lib.optionalString (command.runtimeInputs != [ ]) ''
          export PATH="${lib.makeBinPath command.runtimeInputs}:$PATH"
        ''}
        exec ${lib.escapeShellArg command.script} "$@"
      ''
    ) commands;
  };
}
