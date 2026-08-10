{
  description = "Import a GNOME keyring dump into the Freedesktop Secret Service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs: {
          default = pkgs.writeShellApplication {
            name = "import-keyring";
            runtimeInputs = [
              pkgs.python3
              pkgs.libsecret
              pkgs.systemd # busctl — resolve keyring label → collection path
            ];
            text = ''
              exec python3 ${./import-keyring.py} "$@"
            '';
          };
        }
      );

      apps = forAllSystems (
        pkgs: {
          default = {
            type = "app";
            program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/import-keyring";
          };
        }
      );

      devShells = forAllSystems (
        pkgs: {
          default = pkgs.mkShell {
            packages = [
              pkgs.python3
              pkgs.libsecret
            ];
          };
        }
      );
    };
}
