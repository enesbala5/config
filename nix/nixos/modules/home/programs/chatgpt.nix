{
  config,
  lib,
  unstable,
  ...
}:
let
  cfg = config.modules.home.chatgpt;
in
{
  options.modules.home.chatgpt.enable = lib.mkEnableOption "ChatGPT desktop app";

  config = lib.mkIf cfg.enable {
    # Official Linux desktop app (OpenAI ships a .deb). nixos-26.05 only
    # packages the macOS build (meta.platforms = darwin), so take it from
    # nixpkgs-unstable, which has the Linux launcher + bundled plugins.
    home.packages = [ unstable.chatgpt ];

    # Electron rewrites the bundled plugin manifests, so the launcher copies
    # them to $XDG_CACHE_HOME/chatgpt/bundled-plugins-v2/<store-key>. The
    # package installs this rule to $out/share/user-tmpfiles.d, which NixOS
    # does not read; register it here so caches from previous versions are
    # cleaned up. The launcher recreates the directory if tmpfiles removes it.
    systemd.user.tmpfiles.rules = [
      "e %C/chatgpt/bundled-plugins-v2 - - - 0"
    ];
  };
}
