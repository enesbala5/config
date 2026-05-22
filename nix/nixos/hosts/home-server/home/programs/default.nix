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
      brillo # Brightness Control
      networkmanagerapplet # Network Manager Applet

      hypridle # Idle State
      hyprlock # Lock Screen

      # Documents
      #  ------------------------------------------------------------------------------------------
      libreoffice-qt
      hunspell
      hunspellDicts.en_US

      # Development
      # ------------------------------------------------------------------------------------------
      vscode # IDE
      beekeeper-studio # Database Management
      insomnia # API Client
      neovim # Neovim
      vim # Vim

      # Graphic Design & Video Editing
      # ------------------------------------------------------------------------------------------
      shotcut # Video Editor

      # Tools
      # ------------------------------------------------------------------------------------------
      obsidian # Note Taking App
      typora # Markdown Note Taking & PDF Exporting
      nomacs # Image Viewer

      # Functionality
      # ------------------------------------------------------------------------------------------

    ])
    # Unstable packages
    # ---
    ++ (with unstable; [
      spotify
      telegram-desktop
    ])
    # Flakes
    # ---
    ++ (with inputs; [
      affinity-nix.packages.${system}.default
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
