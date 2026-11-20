{ pkgs }:
let
  source = pkgs.lib.cleanSource ../../.;
in
pkgs.runCommand "render-remote-tests"
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
    bash ${source}/remote/tests/test-render-remote.sh
    touch "$out"
  ''
