{
  inputs,
  pkgs,
  config,
  data,
  lib,
  ...
}:
{
  imports = [
    inputs.zen-browser.homeModules.beta
    # Prefer the flake module: it applies settings via VICINAE_OVERRIDES.
    # HM 25.11's built-in module writes obsolete ~/.config/vicinae/vicinae.json
    # which Vicinae >=0.17 no longer reads.
    inputs.vicinae.homeManagerModules.default
    inputs.hermes-agent.homeManagerModules.default
    ./programs

    ../../../modules/home/programs/opencode
    ../../../modules/home/programs/codex
    ../../../modules/home/programs/antseed
  ];

  disabledModules = [ "programs/vicinae.nix" ];

  # Flake module always assigns programs.google-chrome.nativeMessagingHosts when
  # enable=true. HM 25.11 does not declare that option for proprietary Chrome.
  options.programs.google-chrome.nativeMessagingHosts = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    internal = true;
  };

  config = {
    modules.home.opencode.enable = true;
    modules.home.codex.enable = false;

    # Antseed buyer proxy
    modules.home.antseed.enable = false;

    home.sessionVariables = {
      # Allow all GTK apps to find the xfsettingsd GTK sync module so they
      # don't emit "Failed to load module xfsettingsd-gtk-settings-sync" warnings
      # when xfsettingsd broadcasts the Gtk/Modules XSetting.
      GTK_PATH = "${pkgs.xfce.xfce4-settings}/lib/gtk-3.0";
    };

    home.file =
      let
        pbi = pkgs.kdePackages.plasma-browser-integration;
        chromiumHost = "${pbi}/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json";
      in
      {
        ".config/hypr/hyprlock.conf" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/hypr/hyprlock/configuration.conf";
        };

        ".config/hypr/hypridle.conf" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/hypr/hypridle/configuration.conf";
        };

        ".config/hypr/hyprsunset.conf" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/hypr/hyprsunset/configuration.conf";
        };

        ".config/zed" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/zed";
          recursive = true;
        };

        # Herdr has no home-manager module, so version config.toml here.
        # Only the config file is symlinked; the rest of ~/.config/herdr holds
        # runtime state (sockets, logs, session.json) and must stay writable.
        ".config/herdr/config.toml" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/config.toml";
        };

        # Herdr Auto Title has no home-manager module, so its config is
        # versioned beside Herdr's own. Only the config file is symlinked; the
        # rest of ~/.config/herdr-auto-title holds runtime state (instances,
        # manual-names.json) and must stay writable.
        ".config/herdr-auto-title/config.env" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/herdr/plugins/auto-title/config.env";
        };

        # Pi has no home-manager module, so version its agent config here.
        # settings.json and keybindings.json are symlinked. auth.json,
        # models-store.json (an HTTP cache), sessions/, and Herdr-managed files
        # under extensions/ stay as local runtime state under ~/.pi.
        ".pi/agent/settings.json" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/pi/agent/settings.json";
        };

        # ctrl+backspace should delete a word, not delete the session
        # (pi's default binding for app.session.deleteNoninvasive).
        ".pi/agent/keybindings.json" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/pi/agent/keybindings.json";
        };

        # Custom pi themes (e.g. circus.json, derived from the stylix base16
        # scheme). Whole directory is symlinked so new themes just drop in;
        # pi hot-reloads the active user theme from here.
        ".pi/agent/themes" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/pi/agent/themes";
          recursive = true;
        };

        # Only the extension itself is symlinked; the extensions/ directory
        # also holds herdr-agent-state.ts, which Herdr writes at runtime and
        # must stay writable.
        ".pi/agent/extensions/attach-pasted-images.ts" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/pi/agent/extensions/attach-pasted-images.ts";
        };

        # /rewind: pick a user message to branch the session from, with optional
        # git worktree restore. Single file, so symlink it like the one above.
        ".pi/agent/extensions/rewind.ts" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/pi/agent/extensions/rewind.ts";
        };

        # Ctrl+P inserts "/" into the prompt instead of cycling models.
        ".pi/agent/extensions/ctrl-p-slash.ts" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/pi/agent/extensions/ctrl-p-slash.ts";
        };

        # Ctrl+Shift+\ toggles the pi-sidebar-tui sidebar. The package hardcodes
        # Ctrl+Shift+T; extension shortcuts cannot be remapped via
        # keybindings.json, so this adds a second binding that re-dispatches
        # the package's own /sidebar-tui command.
        ".pi/agent/extensions/sidebar-toggle.ts" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/pi/agent/extensions/sidebar-toggle.ts";
        };

        # Reports the pi session name to Herdr as the pane's agent title, which
        # Herdr's Auto Title plugin names tabs from. A sibling of
        # herdr-agent-state.ts, not a replacement: Herdr rewrites that file on
        # every integration install, so the title hook has to live beside it.
        ".pi/agent/extensions/herdr-pi-title.ts" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/pi/agent/extensions/herdr-pi-title.ts";
        };

        # Modes is a directory extension (index.ts + utils.ts), so the whole
        # directory is symlinked recursively. It owns the normal/plan/ask mode
        # system (Shift+Tab) and replaces the standalone plan-mode extension.
        ".pi/agent/extensions/modes" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/pi/agent/extensions/modes";
          recursive = true;
        };

        ".agents/skills" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/misc/skills";
          recursive = true;
        };

        ".cursor/rules" = {
          source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/misc/rules";
          recursive = true;
        };

        # Plasma Browser Integration native host (Helium)
        ".config/net.imput.helium/NativeMessagingHosts/org.kde.plasma.browser_integration.json".source =
          chromiumHost;
      };

    # Herdr plugin registration lives in ~/.config/herdr/plugins.json, which
    # Herdr rewrites, so home-manager cannot symlink it. Link the local plugin
    # during activation instead, so a fresh machine gets it on first rebuild.
    # Idempotent (only links when missing) and never fails the activation.
    home.activation.herdrLinkAgentHead =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        herdr_bin="${inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/herdr"
        plugin_dir="${data.configDirectory}/tools/herdr/plugins/agent-head"
        registry="$HOME/.config/herdr/plugins.json"
        if [ -x "$herdr_bin" ] && [ -f "$plugin_dir/herdr-plugin.toml" ]; then
          if ! grep -q 'local.agent-head' "$registry" 2>/dev/null; then
            "$herdr_bin" plugin link "$plugin_dir" >/dev/null 2>&1 || true
          fi
        fi
      '';

    systemd.user = {
      services = {
        xfsettingsd = {
          Unit = {
            Description = "xfsettingsd";
            After = [ "graphical-session-pre.target" ];
            PartOf = [ "graphical-session.target" ];
          };

          Install.WantedBy = [ "graphical-session.target" ];

          Service = {
            Environment = [
              "PATH=${data.homeDirectory}/bin"
              "GTK_PATH=${pkgs.xfce.xfce4-settings}/lib/gtk-3.0"
            ];
            ExecStart = "${pkgs.xfce.xfce4-settings}/bin/xfsettingsd";
            Restart = "on-abort";
          };
        };
      };
    };
  };
}
