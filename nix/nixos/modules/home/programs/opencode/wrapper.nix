{
  config,
  lib,
  osConfig,
  pkgs,
  unstable,
  ...
}:

let
  cfg = config.modules.home.opencode;

  # agenix installs this mode 0400. OpenCode rewrites any loaded config that
  # lacks "$schema" and crashes on EACCES (the write is not caught). Unlike
  # rclone, that write does not need to persist, so copy onto tmpfs at launch
  # instead of seeding ~/.config.
  # osConfig, not config.age: this is a home-manager module, and config.age
  # is the /run/user copy. System secrets are at /run/agenix.
  secretsFile = osConfig.age.secrets."opencode-secrets.json".path;
  mcpSecretsFile = osConfig.age.secrets."mcp-secrets.json".path;

  # OpenCode v2 merges this over its writable cli.json. Do not manage that
  # path in Home Manager: OpenCode can replace the file on an in-app save.
  cliPreferences = {
    theme.name = "github";
    attention = {
      enabled = true;
      sound = true;
      volume = 0.4;
    };
    diffs.wrap = "word";
    session = {
      sidebar = "hide";
      scrollbar = true;
      thinking = "show";
    };
    animations = true;
    keybinds = {
      "session.new" = "ctrl+t";
      "session.tab.close" = "ctrl+w";
      "variant.cycle" = "ctrl+alt+t";
      "input.delete.word.backward" = "alt+backspace";
      "session.last" = "ctrl+alt+g,end,ctrl+alt+down";
      "session.first" = "home,alt+home,ctrl+alt+up";
      "which-key.scroll.up" = "ctrl+alt+p";
      "which-key.scroll.down" = "ctrl+alt+n";
      "prompt.editor" = "ctrl+g";
    };
  };

  # Use the unstable package for the v2 CLI preferences above.
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
    export OPENCODE_CLI_CONFIG_CONTENT=${lib.escapeShellArg (builtins.toJSON cliPreferences)}
    # Bearer MCP servers in config.json use {env:VAR}. Same agenix file
    # mcp-sync reads for Cursor, Zed, and pi.
    mcp_secrets=${lib.escapeShellArg mcpSecretsFile}
    if [ -r "$mcp_secrets" ]; then
      eval "$(${lib.getExe pkgs.jq} -r 'to_entries[] | select((.value|type)=="string" and (.key|test("^[A-Za-z_][A-Za-z0-9_]*$"))) | "export \(.key)=\(.value|@sh)"' "$mcp_secrets")"
    fi
    # opencode namespaces its session DB by release channel: only
    # latest/beta/prod use opencode.db, every other channel writes
    # opencode-<channel>.db. The nix package is built as the "stable" channel,
    # so it opened an empty opencode-stable.db and looked like sessions were
    # lost, while prior installs had written opencode.db. Force the shared DB
    # so history survives channel/version switches.
    export OPENCODE_DISABLE_CHANNEL_DB=true

    exec ${lib.getExe unstable.opencode} "$@"
  '';
in
{
  config = lib.mkIf cfg.enable {
    programs.opencode.package = wrappedOpencode;
  };
}
