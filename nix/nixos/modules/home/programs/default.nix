{
  pkgs,
  unstable,
  data,
  inputs,
  system,
  ...
}:
{
  imports = [
    # shell
    ./zsh.nix

    ./git.nix

    # window manager / desktop stuff
    ./waybar # status bar
    # ./hyprland # window manager
    # ./tofi.nix # app launcher

    ./dunst.nix # notification daemon
    ./kitty.nix # terminal emulator

    # ./firefox # web browser
    # ./spicetify.nix # spotify retheming
  ];

  home.packages =
    (with pkgs; [
      # System
      # ------------------------------------------------------------------------------------------
      dunst # Notification Daemon
      brillo # Brightness Control

      # Shell
      # ------------------------------------------------------------------------------------------
      zsh
      zsh-powerlevel10k
      fzf
      zoxide # Faster cd
      tree # display contents of a directory as a file tree
      which # find locations of executables
      bat # Text Preview
      neofetch # Display system info

      # Audio
      # ------------------------------------------------------------------------------------------
      playerctl # useful tui for controlling media

      # User Interface
      # ------------------------------------------------------------------------------------------
      hyprpicker # Color Picker
      hyprcursor # Cursor Manager
      # hyprshade # Display Hue

      # ---
      # Wallpaper
      waypaper
      swaybg
      # Dock for Hyprland

      # Development
      # ------------------------------------------------------------------------------------------
      devenv # Super Easy Development Environments, esp w/ direnv
      gh # Github CLI
      lazydocker # Docker TUI
      cloudflared # Cloudflare Tunnel

      # ---
      # Nix Language
      nixd
      nixfmt-rfc-style

      # ---
      # LaTex
      texlive.combined.scheme-full

      # Tools
      # ------------------------------------------------------------------------------------------

      unzip # Unzip Files
      p7zip # 7zip
      vlc # Media Player
      btop # Process Viewer

      openssl # SSL Certificates

      gparted
      # rquickshare

      file

      # Functionality
      # ------------------------------------------------------------------------------------------
      grim # screenshot utility
      slurp # for selecting parts of the screen

      cliphist # Clipboard History
      xdg-utils # open links in browser
      wl-clipboard # clipboard utilities (wl-copy & wl-paste)
      blueman
      sshpass
      pasystray
      appimage-run

      qbittorrent # qt torrent client
      transmission_4-gtk # gtk torrent client

      pulsemixer # audio control
      pulseaudio # provides pactl (client only, talks to PipeWire pulse socket)

      stremio # Video Streaming
    ])
    # Unstable packages
    # ---
    ++ (with unstable; [
      google-chrome # Web Browser
    ])
    # Flakes
    # ---
    ++ (with inputs; [
      hyprdynamicmonitors.packages.${system}.default
      helium-browser.packages.${system}.default
    ]);

  programs = {
    rofi = {
      enable = true;
      package = pkgs.wofi;
      # theme = "${data.configDirectory}/tools/rofi/theme.rasi";
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
    };
  };

  stylix = {
    enable = true;
    polarity = "dark";
    autoEnable = true;

    # gtk.iconTheme.package = pkgs.papirus-icon-theme;
    # gtk.iconTheme.name = "Papirus";

    base16Scheme = data.schemes.dark;

    fonts = {
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };

      sansSerif = {
        package = pkgs.geist-font;
        name = "Geist Medium";
      };

      monospace = {
        name = "Fira Code Retina";
        package = pkgs.fira-code;
      };
    };

    # cursor = {
    #   # name = "Capitaine Cursors";
    #   name = "Bibata-Modern-Classic";
    #   size = 5;
    #   package = pkgs.bibata-cursors;
    #   # gtk.enable = true;
    #   # x11.enable = true;
    # };

    opacity = {
      desktop = 0.3;
      applications = 0.7;
      terminal = 0.8;
      popups = 0.8;
    };

    targets = {
      waybar.enable = true;
      rofi.enable = false;
      dunst.enable = false;
      zed.enable = true;
      vicinae.enable = true;
    };
  };

  # ------------------------------------------------------------------------------------------
  # Services
  # ------------------------------------------------------------------------------------------

  services = {
    udiskie.enable = true;
  };
}
