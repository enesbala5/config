{
  inputs = {
    # NixOS inputs
    # ------------------------------------------------------------------------------------------

    # Base
    # ---
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-26.05";
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
      url = "github:nix-community/home-manager/release-26.05";
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
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprdynamicmonitors = {
      url = "github:fiffeek/hyprdynamicmonitors?rev=10a993e2e13fc5be4d3057f9331f91c335d24d30";
    };

    # Framework-13
    # ---
    # Do not set inputs.nixpkgs.follows here. That misses vicinae.cachix.org.
    vicinae = {
      url = "github:vicinaehq/vicinae/v0.29.2";
    };

    vicinae-extensions = {
      url = "github:vicinaehq/extensions?rev=0e3953058fb787d2a96e5ac0cec462440c07cd07";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.vicinae.follows = "vicinae";
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

    dbflux = {
      url = "github:0xErwin1/dbflux";
    };

    antseed = {
      url = "github:AntSeed/antseed";
      # antseed's flake builds the CLI bundle and pins the native prebuilds
      # (better-sqlite3, node-datachannel, keytar) against its own nixpkgs and a
      # pnpm fetch hash, so keep it off ours like pi/hermes rather than forcing
      # `inputs.nixpkgs.follows`.
    };

    # herdr 0.9.5 from the nixpkgs-unstable channel on 2026-11-04, on
    # cache.nixos.org. The herdr flake tracks master past that tag and has
    # no binary cache. herdr-desktop / herdr-core in this pin are 0.1.10 /
    # 0.1.15, behind the Linux fixes in the 0.1.13 / 0.1.18 release
    # tarballs, so the desktop module does not use them.
    nixpkgs-herdr = {
      url = "github:NixOS/nixpkgs/9d3b8db48266c17be0b5f9c6360c3ecfbac3d1f5";
    };

    dsh-nix = {
      url = "github:Samuka007/dsh-nix";
      # pkgs/dsh.nix sets fetchPnpmDeps.fetcherVersion = 4, which nixos-25.11
      # rejects, and the pnpm-deps hash only matches the nixpkgs rev in
      # dsh-nix's own flake.lock. A floating nixos-unstable recomputes it.
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/0e251e24a4f24e036a084b6b4b2d2491af4167f4";
    };

    herdr-gpui = {
      url = "github:penso/herdr-gpui/v20261006.1";
      # Native GPUI client for the local herdr daemon; also pins its own nixpkgs + rust-overlay.
    };

    pi = {
      url = "github:earendil-works/pi/stable";
      # Pi's own nix/package.nix builds the Node bundle with importNpmLock, so
      # keep it on its pinned nixpkgs instead of forcing ours.
    };

    # Same pattern as zaku: fetch from GitHub so root rebuilds do not need
    # self.submodules / local submodule checkouts (libgit2 ownership traps).
    omacut = {
      url = "github:enesbala5/omacut-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    zaku = {
      url = "github:enesbala5/zaku-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Hyprland 0.56.2 from nixpkgs, on cache.nixos.org. The Hyprland flake for
    # this tag is not cached. Separate from nixpkgs-unstable, which is still
    # on Hyprland 0.55.4.
    nixpkgs-hyprland = {
      url = "github:NixOS/nixpkgs/8edc0c72e3a38faf5434e40d1f19431125fe4b30";
    };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      # Do NOT `follows` another nixpkgs.
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixos-hardware,
      home-manager,
      hermes-agent,
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
            thunar-archive-plugin = prev.thunar-archive-plugin.overrideAttrs (old: {
              postInstall = (old.postInstall or "") + ''
                cp ${final.xarchiver}/libexec/thunar-archive-plugin/* $out/libexec/thunar-archive-plugin/
              '';
            });
          })
          # Passwordless keyrings are GKeyFile text. g_key_file_set_value()
          # writes a secret with a raw newline, and the next daemon start
          # rejects the whole file ("invalid or unrecognized format").
          # g_key_file_set_string() escapes newlines; the reader already uses
          # g_key_file_get_string(). Proton SSO is what writes those newlines.
          (final: prev: {
            gnome-keyring = prev.gnome-keyring.overrideAttrs (old: {
              postPatch = (old.postPatch or "") + ''
                substituteInPlace pkcs11/secret-store/gkm-secret-textual.c \
                  --replace-fail \
                  'g_key_file_set_value (file, identifier, "secret", (gchar*)secret);' \
                  'g_key_file_set_string (file, identifier, "secret", (gchar*)secret);'
              '';
            });
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
