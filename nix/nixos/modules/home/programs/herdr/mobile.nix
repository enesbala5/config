{
  config,
  lib,
  inputs,
  data,
  system,
  ...
}:
let
  cfg = config.modules.home.herdr;
  herdrPkgs = inputs.nixpkgs-herdr.legacyPackages.${system};
  herdrPkg = herdrPkgs.herdr;
  # Ovis needs Bun 1.4 or newer. nixpkgs 26.05 has 1.3.13.
  bun = herdrPkgs.bun;
in
{
  options.modules.home.herdr.mobile.enable = lib.mkEnableOption "Ovis phone access";

  config = lib.mkIf (cfg.enable && cfg.mobile.enable) {
    home.packages = [ bun ];

    # herdr starts plugin commands with its own PATH. Ovis only looks in
    # ~/.local/bin (and a few other fixed places) when that PATH has no bun.
    home.file.".local/bin/bun".source = lib.getExe bun;

    # Plugin settings. Ovis reads `env`, not `.env`.
    # OVIS_RUNTIME=herdr-core: the desktop app's terminals, not the TUI.
    # OVIS_TAILSCALE_SERVE_ONLY keeps the Ovis relay off.
    home.file.".config/herdr/plugins/config/devswha.ovis/env" = {
      source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/plugins/ovis/env";
    };

    # Registration is runtime state in plugins.json. Idempotent, and a
    # failure here does not fail activation. Bun has to be on PATH: herdr
    # runs the plugin build with this script's environment.
    home.activation.herdrInstallOvis = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${bun}/bin:${herdrPkg}/bin:$PATH"
      herdr_bin="${herdrPkg}/bin/herdr"
      registry="$HOME/.config/herdr/plugins.json"
      if [ -x "$herdr_bin" ]; then
        if ! grep -q 'devswha.ovis' "$registry" 2>/dev/null; then
          "$herdr_bin" plugin install devswha/ovis --yes >/dev/null 2>&1 || true
        fi
      fi
    '';
  };
}
