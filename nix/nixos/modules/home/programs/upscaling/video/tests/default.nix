{ pkgs }:
let
  python = pkgs.python3.withPackages (ps: [ ps.pillow ]);
  source = pkgs.lib.cleanSource ../.;
in
pkgs.runCommand "upscale-video-tests"
  {
    nativeBuildInputs = [
      python
      pkgs.ffmpeg
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    export PYTHONDONTWRITEBYTECODE=1
    mkdir -p "$HOME"
    python3 -m unittest discover -s ${source}/tests -v
    touch "$out"
  ''
