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
      agenix,
      ...
    }:
    let
      lib = nixpkgs.lib;

      data = {
        username = "e";
        uid = 1000;
        fullName = "Enes Bala";
        email = "contact@enesbala.com";

        # Directories
        homeDirectory = "/home/${data.username}";
        configDirectory = "${data.homeDirectory}/config";

        # Google Drive
        googleDriveRemoteName = "gdrive";
        googleDriveLocalDir = "${data.homeDirectory}/gdrive";
        # Writable copy of agenix rclone-conf (token refresh); seeded on activation
        rcloneGdriveConfigPath = "${data.homeDirectory}/.config/rclone/rclone.conf";

        schemes = {
          light = "${data.configDirectory}/misc/scheme/google-light.yaml";
          dark = "${data.configDirectory}/misc/scheme/circus.yaml";
        };
      };

      system = "x86_64-linux";

      pkgs = import nixpkgs {
        system = system;
        config.allowUnfree = true;
        overlays = [
          # Fix thunar-archive-plugin not finding xarchiver.tap
          # https://github.com/NixOS/nixpkgs/issues/248192
          (final: prev: {
            xfce = prev.xfce.overrideScope (
              xfinal: xprev: {
                thunar-archive-plugin = xprev.thunar-archive-plugin.overrideAttrs (old: {
                  postInstall = (old.postInstall or "") + ''
                    cp ${final.xarchiver}/libexec/thunar-archive-plugin/* $out/libexec/thunar-archive-plugin/
                  '';
                });
              }
            );
          })
        ];
      };

      unstable = import nixpkgs-unstable {
        system = system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations = {

        framework-13 = lib.nixosSystem {
          inherit pkgs;

          specialArgs = {
            hostname = "framework-13";

            inherit inputs;
            inherit data;
            inherit system;
            inherit unstable;
          };

          modules = [
            nixos-hardware.nixosModules.framework-13-7040-amd
            home-manager.nixosModules.default
            ./modules/base-configuration.nix
            ./hosts/framework-13/hardware-configuration.nix
            ./hosts/framework-13/default.nix
            agenix.nixosModules.default
          ];
        };

        home-server = lib.nixosSystem {
          inherit pkgs;

          specialArgs = {
            hostname = "home-server";

            inherit inputs;
            inherit data;
            inherit system;
            inherit unstable;
          };

          modules = [
            home-manager.nixosModules.default
            ./modules/base-configuration.nix
            ./hosts/home-server/hardware-configuration.nix
            ./hosts/home-server/default.nix
            agenix.nixosModules.default
          ];
        };
      };
    };
}
