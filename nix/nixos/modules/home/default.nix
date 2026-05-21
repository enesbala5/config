{
  config,
  inputs,
  system,
  data,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.agenix.homeManagerModules.default
    inputs.hyprdynamicmonitors.homeManagerModules.default
    inputs.stylix.homeModules.stylix
    ./programs
  ];

  age = {
    identityPaths = [ "${data.homeDirectory}/.ssh/id_ed25519" ];
    secrets =
      let
        secrets = import ../../../secrets/secrets.nix;
      in
      lib.mapAttrs' (
        name: attrs:
        lib.nameValuePair (lib.removeSuffix ".age" name) {
        file = ../../../secrets/${name};
        }
      ) secrets;
  };

  # Home Manager configuration
  home.username = data.username;
  home.homeDirectory = data.homeDirectory;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # ------------------------------------------------------------------------------------------
  # Programs & Generic Installs
  # ------------------------------------------------------------------------------------------

  # Symlinks
  home = {
    file = {
      ".config/hypr/hyprland.conf" = {
        source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/hypr/hyprland/configuration.conf";
      };

      ".config/hyprdynamicmonitors/" = {
        source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/hyprdynamicmonitors/";
        recursive = true;
      };

      # Typora
      ".config/Typora/themes" = {
        source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/tools/typora/themes/";
        recursive = true;
      };
    };

    pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      # package = pkgs.capitaine-cursors-themed;
      # name = "Capitaine Cursors";

      size = 10;
    };

    sessionVariables = {
      EDITOR = "zeditor";

      # Add XDG Base Directory specification variables
      XDG_CONFIG_HOME = "${data.homeDirectory}/.config";
      # XDG_CURRENT_DESKTOP = "X-NIXOS-SYSTEMD-AWARE";
      XDG_CACHE_HOME = "${data.homeDirectory}/.cache";
      XDG_DATA_HOME = "${data.homeDirectory}/.local/share";
      XDG_STATE_HOME = "${data.homeDirectory}/.local/state";
    };

    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    #
    # You should not change this value, even if you update Home Manager. If you do
    # want to update the value, then make sure to first check the Home Manager
    # release notes.
    stateVersion = "23.11"; # Please read the comment before changing.
  };

  gtk = {
    enable = true;
  };

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  wayland.windowManager.hyprland.systemd.enable = true;
  wayland.windowManager.hyprland.systemd.variables = [ "--all" ];
}
