{
  description = "A dead-simple Qt6 video length trimmer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "omacut";
            version = "unstable-2026-08-07";

            src = pkgs.fetchFromGitHub {
              owner = "omacom-io";
              repo = "omacut";
              rev = "0948c4615d45ac62727b8c69112178e09781b7a4";
              hash = "sha256-vnncMfpx/mH6MZ0K1RIP498qAjOG+hf8Sdko+MVEX9w=";
            };

            nativeBuildInputs = [
              pkgs.qt6.qmake
              pkgs.qt6.wrapQtAppsHook
              pkgs.pkg-config
            ];

            buildInputs = [
              pkgs.qt6.qtbase
              pkgs.qt6.qtdeclarative
              pkgs.qt6.qtmultimedia
            ];

            # omacut invokes ffmpeg/ffprobe and xdg-desktop-portal at runtime
            qtWrapperArgs = [
              "--prefix PATH : ${pkgs.lib.makeBinPath [
                pkgs.ffmpeg
                pkgs.xdg-desktop-portal
              ]}"
            ];

            installPhase = ''
              runHook preInstall
              install -Dm755 build/omacut $out/bin/omacut 2>/dev/null || install -Dm755 omacut $out/bin/omacut

              if [ -d pkgbuild ]; then
                install -Dm644 pkgbuild/omacut.desktop -t $out/share/applications/ 2>/dev/null || true
                if [ -f pkgbuild/omacut.svg ]; then
                  install -Dm644 pkgbuild/omacut.svg $out/share/icons/hicolor/scalable/apps/omacut.svg
                elif [ -f pkgbuild/omacut.png ]; then
                  install -Dm644 pkgbuild/omacut.png -t $out/share/pixmaps/
                fi
              fi
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "A dead-simple Qt Quick video length trimmer";
              homepage = "https://github.com/omacom-io/omacut";
              license = licenses.mit;
              mainProgram = "omacut";
              platforms = platforms.linux;
            };
          };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/omacut";
        };
      });
    };
}
