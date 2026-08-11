{
  pkgs,
  config,
  inputs,
  system,
  unstable,
  data,
  ...
}:
{
  home.packages =
    (with pkgs; [
      # System
      # ------------------------------------------------------------------------------------------
      dunst # Notification Interface
      networkmanagerapplet # Network Manager Applet

      # Development
      # ------------------------------------------------------------------------------------------
      neovim # Neovim
      vim # Vim

      # Tools
      # ------------------------------------------------------------------------------------------
      nomacs # Image Viewer

      # Functionality
      # ------------------------------------------------------------------------------------------

    ])
    # Unstable packages
    # ---
    ++ (with unstable; [
    ])
    # Flakes
    # ---
    ++ (with inputs; [
      cursor-nix.packages.${system}.cursor-cli
    ]);

  programs = {
    ssh = {
      enable = true;

      matchBlocks."*" = {
        forwardAgent = false;
        addKeysToAgent = "yes";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };

      includes = [ config.age.secrets.home-server-ssh-config.path ];
    };
  };

  services = { };
}
