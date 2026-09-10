{
  inputs = {
    # NixOS inputs
    # ------------------------------------------------------------------------------------------

    # Base
    # ---
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-25.11";
    };

    nixpkgs-unstable = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
    };

    # Home Manager inputs
    # ------------------------------------------------------------------------------------------

    # Base
    # ---
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprdynamicmonitors = {
      url = "github:fiffeek/hyprdynamicmonitors?rev=10a993e2e13fc5be4d3057f9331f91c335d24d30";
    };

    # Touchscreen/trackpad gesture plugin (4-finger taps etc). Pinned for Hyprland v0.51.1.
    hyprgrass = {
      url = "github:horriblename/hyprgrass?rev=ad51f4649a1c054d788fb6ce2a2bfcdfac28d524";
      inputs.hyprland.follows = "hyprland";
    };

    # Framework-13
    # ---
    vicinae = {
      url = "github:vicinaehq/vicinae/v0.24.0";
    };

    vicinae-extensions = {
      url = "github:vicinaehq/extensions?rev=22bc47b8ad1907a8aaeec502696a8202fac64a00";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    affinity-nix = {
      url = "github:mrshmllow/affinity-nix?rev=f76f97513153a753718aa1423e84b4cb8ea4c185";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake/beta";

      inputs = {
        # IMPORTANT: To ensure compatibility with the latest Firefox version, use nixpkgs-unstable.
        nixpkgs.follows = "nixpkgs-unstable";
        home-manager.follows = "home-manager";
      };
    };

    helium-browser = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprshutdown = {
      url = "github:hyprwm/hyprshutdown?rev=f70097e670adddb5a02fb0994804532d6b483b72";
    };

    aw-watcher-window-hyprland = {
      url = "github:bobvanderlinden/aw-watcher-window-hyprland";
    };

    zed-editor = {
      url = "github:zed-industries/zed/nightly";
    };

    cursor-nix = {
      url = "github:tomsch/cursor-nix";
    };

    grok-bot = {
      url = "github:jordangarrison/grok-bot-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    omacut = {
      url = "path:./hosts/framework-13/home/programs/omacut";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    hyprland = {
      url = "github:hyprwm/Hyprland/v0.51.1";

      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
      };
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixos-hardware,
      home-manager,
      plasma-manager,
      agenix,
      stylix,
      hyprland,
      hyprgrass,
      hyprdynamicmonitors,
      vicinae,
      vicinae-extensions,
      affinity-nix,
      zen-browser,
      helium-browser,
      hyprshutdown,
      aw-watcher-window-hyprland,
      zed-editor,
      cursor-nix,
      grok-bot,
      antigravity-nix,
      omacut,
      ...
    }@{
      inherit self;
      ...
    }: {}
  };
}
