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
      enableDefaultConfig = false;

      settings."*" = {
        ForwardAgent = false;
        AddKeysToAgent = "yes";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };

      includes = [ config.age.secrets.home-server-ssh-config.path ];
    };
  };

  services = { };
}
