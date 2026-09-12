# Hermes Desktop (Electron) + `hermes` CLI, via the flake's Home Manager module.
#
# Deliberately no `services.hermes-agent` here: without it the desktop app
# starts and owns its own backend, so no gateway/backend daemon runs. The
# `hermes` CLI is installed so first-run setup and config edits work normally
# (nothing sets HERMES_MANAGED, so the CLI is not blocked).
{
  ...
}:
{
  programs.hermes-agent = {
    enable = true;
    desktop.enable = true;
  };
}
