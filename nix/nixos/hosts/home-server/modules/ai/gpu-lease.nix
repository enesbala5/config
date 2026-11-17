{
  pkgs,
  lib,
}:
pkgs.writeShellScriptBin "gpu-lease" ''
  set -euo pipefail
  shopt -s inherit_errexit nullglob
  systemctl_bin="''${GPU_LEASE_SYSTEMCTL:-${pkgs.systemd}/bin/systemctl}"
  tool_path="${
    lib.makeBinPath [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.sudo
    ]
  }"
  ${builtins.readFile ./gpu-lease.sh}
''
