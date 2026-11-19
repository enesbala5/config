{ pkgs }:
let
  source = pkgs.lib.cleanSource ../.;
in
pkgs.runCommand "upscale-remote-tests"
  {
    nativeBuildInputs = with pkgs; [
      bash
      coreutils
      gnused
      gnugrep
      jq
      rsync
      util-linux
    ];
  }
  ''
    bash ${source}/tests/test-upscale-remote.sh
    touch "$out"
  ''
