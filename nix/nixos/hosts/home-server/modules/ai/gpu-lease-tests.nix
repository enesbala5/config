{ pkgs }:
let
  gpuLease = import ./gpu-lease.nix { inherit pkgs; inherit (pkgs) lib; };
  fakeSystemctl = pkgs.writeShellScript "fake-systemctl" ''
    set -eu
    printf '%s\n' "$*" >> "$GPU_LEASE_LOG"
    case "$1" in
      is-active)
        test -f "$GPU_LEASE_ACTIVE_FILE"
        ;;
      stop)
        rm -f "$GPU_LEASE_ACTIVE_FILE"
        ;;
      start) ;;
      *)
        echo "unexpected systemctl invocation: $*" >&2
        exit 99
        ;;
    esac
  '';
in
pkgs.runCommand "gpu-lease-tests"
  {
    nativeBuildInputs = [
      gpuLease
      pkgs.bash
      pkgs.shellcheck
      pkgs.util-linux
      pkgs.diffutils
    ];
  }
  ''
    set -euo pipefail
    shellcheck ${gpuLease}/bin/gpu-lease

    work="$TMPDIR/lease"
    mkdir -p "$work"
    export GPU_LEASE_TEST=1
    export GPU_LEASE_SYSTEMCTL=${fakeSystemctl}
    export GPU_LEASE_VRAM_WAIT=0

    fail() {
      printf 'FAIL: %s\n' "$1" >&2
      exit 1
    }

    setup() {
      rm -rf "$work/case"
      mkdir -p "$work/case/sys/card0/device"
      export GPU_LEASE_LOCK="$work/case/lease.lock"
      export GPU_LEASE_SYSFS="$work/case/sys"
      export GPU_LEASE_LOG="$work/case/systemctl.log"
      export GPU_LEASE_ACTIVE_FILE="$work/case/active"
      : > "$GPU_LEASE_LOG"
    }

    assert_log() {
      local expected="$1"
      diff -u "$expected" "$GPU_LEASE_LOG" || fail "systemctl log mismatch"
    }

    # active → stop, run payload, start
    setup
    touch "$GPU_LEASE_ACTIVE_FILE"
    echo 100 > "$work/case/sys/card0/device/mem_info_vram_used"
    gpu-lease -- ${pkgs.bash}/bin/bash -c 'echo payload >> "$GPU_LEASE_LOG"'
    printf '%s\n' \
      "is-active --quiet llama-cpp.service" \
      "stop llama-cpp.service" \
      "payload" \
      "start llama-cpp.service" \
      > "$work/case/expected"
    assert_log "$work/case/expected"
    test ! -f "$GPU_LEASE_ACTIVE_FILE"

    # already inactive → no start
    setup
    echo 100 > "$work/case/sys/card0/device/mem_info_vram_used"
    gpu-lease -- ${pkgs.bash}/bin/bash -c 'echo payload >> "$GPU_LEASE_LOG"'
    printf '%s\n' \
      "is-active --quiet llama-cpp.service" \
      "payload" \
      > "$work/case/expected"
    assert_log "$work/case/expected"

    # payload exits non-zero → still start
    setup
    touch "$GPU_LEASE_ACTIVE_FILE"
    echo 100 > "$work/case/sys/card0/device/mem_info_vram_used"
    status=0
    gpu-lease -- ${pkgs.bash}/bin/bash -c 'exit 7' || status=$?
    test "$status" -eq 7 || fail "expected exit 7, got $status"
    printf '%s\n' \
      "is-active --quiet llama-cpp.service" \
      "stop llama-cpp.service" \
      "start llama-cpp.service" \
      > "$work/case/expected"
    assert_log "$work/case/expected"

    # lock held → exit before any systemctl call
    setup
    echo 100 > "$work/case/sys/card0/device/mem_info_vram_used"
    exec 8>"$GPU_LEASE_LOCK"
    flock -n 8
    status=0
    gpu-lease -- ${pkgs.coreutils}/bin/true || status=$?
    flock -u 8
    test "$status" -ne 0 || fail "expected lock contention to fail"
    test ! -s "$GPU_LEASE_LOG" || fail "systemctl ran while the lock was held"

    # VRAM stays above 1 GiB → do not run the payload; restore llama
    setup
    touch "$GPU_LEASE_ACTIVE_FILE"
    echo 2147483648 > "$work/case/sys/card0/device/mem_info_vram_used"
    status=0
    gpu-lease -- ${pkgs.bash}/bin/bash -c 'echo payload >> "$GPU_LEASE_LOG"' || status=$?
    test "$status" -ne 0 || fail "expected high VRAM to fail"
    printf '%s\n' \
      "is-active --quiet llama-cpp.service" \
      "stop llama-cpp.service" \
      "start llama-cpp.service" \
      > "$work/case/expected"
    assert_log "$work/case/expected"

    touch "$out"
  ''
