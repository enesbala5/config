{
  config,
  lib,
  pkgs,
  unstable,
  data,
  ...
}:

let
  cfg = config.modules.home.opencode;

  # agenix installs this mode 0400. OpenCode rewrites any loaded config that
  # lacks "$schema" and crashes on EACCES (the write is not caught). Unlike
  # rclone, that write does not need to persist, so copy onto tmpfs at launch
  # instead of seeding ~/.config.
  secretsFile = "/run/user/${toString data.uid}/agenix/opencode-secrets.json";

  # nixos-25.11 ships opencode 1.1.14, which predates the TUI "attention"
  # sounds feature (see tui.nix). unstable is 1.17+, so run that instead.
  wrappedOpencode = pkgs.writeShellScriptBin "opencode" ''
    set -eu
    runtime="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    src=${lib.escapeShellArg secretsFile}
    dst="$runtime/opencode/opencode-secrets.json"
    if [ ! -r "$src" ]; then
      echo "opencode: cannot read $src" >&2
      exit 1
    fi
    install -d -m 700 "$runtime/opencode"
    install -m 600 "$src" "$dst"
    export OPENCODE_CONFIG="$dst"
    exec ${lib.getExe unstable.opencode} "$@"
  '';
in
{
  config = lib.mkIf cfg.enable {
    programs.opencode.package = wrappedOpencode;
  };
}
