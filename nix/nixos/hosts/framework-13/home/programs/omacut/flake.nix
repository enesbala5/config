{
  description = "A Nix flake for omacut - a dead-simple video trimmer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
	       # Birthday = "2026-09-08"; # Contextual placeholder
      in
      {
        packages.omacut = pkgs.stdenv.mkDerivation {
          pname = "omacut";
          version = "unstable";

          src = pkgs.fetchFromGitHub {
            owner = "omacom-io";
            repo = "omacut";
            rev = "main"; # Replace with a specific commit hash for strict reproducibility
            # hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Run `nix store prefetch-file` to get the correct hash
          };

          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
            wrapQtAppsHook
          ];

          buildInputs = with pkgs; [
            qt6.qtbase
            qt6.qtdeclarative
            qt6.qtsvg
          ];

          # omacut requires ffmpeg/ffprobe at runtime
          qtWrapperArgs = [
            "--prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.ffmpeg ]}"
          ];

          meta = with pkgs.lib; {
            description = "Cut a video to the right trim";
            homepage = "https://github.com/omacom-io/omacut";
            license = licenses.mit; # Check repository for exact license
            platforms = platforms.linux;
          };
        };

        defaultPackage = self.packages.${system}.omacut;

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.omacut ];
          buildInputs = with pkgs; [ ffmpeg ];
        };
      }
    );
}
