#!/usr/bin/env bash
# render-remote and render-worker against a fake server. `ssh` runs the remote
# command locally in a scratch "render host home"; rsync is real and uses that
# ssh. Only make, blender, ffmpeg, gpu-lease and xvfb-run are stand-ins; the
# real render-worker script is exercised. Needs bash, coreutils, sed, jq,
# rsync, util-linux.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
client="$here/../render-remote.sh"
worker="$here/../../server/render-worker.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export FAKE_REMOTE_HOME="$work/remote-home"
export HOME="$work/laptop-home"
export XDG_STATE_HOME="$work/state"
export RENDER_REMOTE_HOST=fakehost
export RENDER_REMOTE_ROOT=render-jobs
export RENDER_REMOTE_POLL=0.1
export RENDER_REMOTE_MAX_UNREACHABLE=3
mkdir -p "$FAKE_REMOTE_HOME" "$HOME" "$work/bin" "$work/comp/blender" "$work/input" "$work/other"
printf '{"engine":"EEVEE","duration":1,"fps":4}\n' >"$work/comp/scene.json"
printf 'entry\n' >"$work/comp/blender/main.py"
mkdir -p "$work/comp/out"
printf 'stale\n' >"$work/comp/out/old-frame.png"
printf 'take\n' >"$work/input/take.mp4"
printf 'other\n' >"$work/other/take.mp4"
: >"$work/calls"

# --- fakes -------------------------------------------------------------------

cat >"$work/bin/ssh" <<'EOF'
#!/usr/bin/env bash
# ssh [-o X]... HOST COMMAND...: run COMMAND locally inside the fake remote home.
if [[ -n "${FAKE_SSH_DOWN:-}" ]]; then echo "ssh: unreachable" >&2; exit 255; fi
while [[ "${1:-}" == -* ]]; do
  if [[ "$1" == -o ]]; then shift 2; else shift; fi
done
shift # host
cd "$FAKE_REMOTE_HOME"
if [[ "${1:-}" == bash && "${2:-}" == -s ]]; then
  shift 2
  exec bash -s "$@"
else
  exec bash -c "$*"
fi
EOF

cat >"$work/bin/gpu-lease" <<'EOF'
#!/usr/bin/env bash
echo lease >>"$FAKE_CALLS"
shift # --
exec "$@"
EOF

cat >"$work/bin/xvfb-run" <<'EOF'
#!/usr/bin/env bash
echo xvfb >>"$FAKE_CALLS"
shift # -a
exec "$@"
EOF

cat >"$work/bin/blender" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$work/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$work/bin/make" <<'EOF'
#!/usr/bin/env bash
# Just enough of make -C to produce the files the render contract expects.
target="" out=""
while (($#)); do
  case "$1" in
    -C) shift; cd "$1" ;;
    look | render) target=$1 ;;
    OUT=*) out=${1#OUT=} ;;
  esac
  shift
done
[[ -n "$out" ]] || exit 64
mkdir -p "$out/frames"
if [[ "$target" == look ]]; then
  printf 'still\n' >"$out/still.png"
  exit 0
fi
n=${FAKE_FRAMES:-4}
for ((i = 1; i <= n; i++)); do
  printf 'frame\n' >"$out/frames/$(printf '%04d' "$i").png"
  if [[ -n "${FAKE_FAIL:-}" && "$i" -ge "$FAKE_FAIL" ]]; then
    echo "fake make exploded at frame $i" >&2
    exit 7
  fi
  sleep "${FAKE_FRAME_SLEEP:-0}"
done
printf 'mp4\n' >"$out/macbook.mp4"
EOF

# The real worker, with a short poll and the fake tools on PATH.
{
  printf '#!%s\n' "$(command -v bash)"
  printf 'export PATH="%s:$PATH"\n' "$work/bin"
  printf 'export RENDER_WORKER_POLL=0.1\n'
  cat "$worker"
} >"$work/bin/render-worker"
# The Nix sandbox has no /usr/bin/env.
sed -i "1s|.*|#!$(command -v bash)|" "$work/bin/"*
chmod +x "$work/bin"/*
export FAKE_CALLS="$work/calls"
export PATH="$work/bin:$PATH"

# --- harness -----------------------------------------------------------------

fails=0
run() { # run <name> <expected exit> <args...>; output in $work/out.txt
  local name=$1 want=$2 got=0
  shift 2
  bash -euo pipefail "$client" "$@" >"$work/out.txt" 2>&1 || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "FAIL $name: exit $got, wanted $want"
    sed 's/^/    /' "$work/out.txt"
    fails=$((fails + 1))
    return 1
  fi
}
expect() { # expect <name> <grep pattern>; pattern must appear in the last output
  if ! grep -q -- "$2" "$work/out.txt"; then
    echo "FAIL $1: output lacks '$2'"
    sed 's/^/    /' "$work/out.txt"
    fails=$((fails + 1))
  fi
}
check() { # check <name> <test args...>
  local name=$1
  shift
  if ! "$@"; then
    echo "FAIL $name"
    fails=$((fails + 1))
  fi
}

comp="$work/comp"
rec="$work/input/take.mp4"
out="$work/out"

base=(run --job happy --out "$out" --progress 'out/frames/*.png:4'
  --pull 'out/macbook.mp4' --upload "$rec" --gpu "$comp"
  -- make -C src render OUT=../out RECORDING=../in/take.mp4)

# 1. happy path: sync, run under gpu-lease + xvfb, watch progress, pull output
if run happy 0 "${base[@]}"; then
  expect happy "all done"
  expect happy "4/4 (100%)"
  expect happy "pulled macbook.mp4"
  check happy-result test "$(cat "$out/macbook.mp4")" = mp4
  check happy-src test -f "$FAKE_REMOTE_HOME/render-jobs/happy/src/scene.json"
  check happy-no-out test ! -e "$FAKE_REMOTE_HOME/render-jobs/happy/src/out/old-frame.png"
  check happy-upload test -f "$FAKE_REMOTE_HOME/render-jobs/happy/in/take.mp4"
  check happy-lease grep -q lease "$work/calls"
  check happy-xvfb grep -q xvfb "$work/calls"
fi

# 2. rerun: the finished output is already local
if run rerun 0 "${base[@]}"; then
  expect rerun "nothing to do"
fi

# 3. failure: stopped at frame 2, error reported, no output pulled
: >"$work/calls"
export FAKE_FAIL=2
if run failure 1 run --job flaky --out "$work/out-f" --progress 'out/frames/*.png:4' \
  --pull 'out/macbook.mp4' --upload "$rec" "$comp" \
  -- make -C src render OUT=../out RECORDING=../in/take.mp4; then
  expect failure "job failed"
  expect failure "fake make exploded"
  check failure-no-pull test ! -e "$work/out-f/macbook.mp4"
fi
unset FAKE_FAIL

# 4. --look has no progress and does not use the GPU path
: >"$work/calls"
if run look 0 run --job look --out "$work/out-l" --pull 'out/still.png' \
  --upload "$rec" "$comp" \
  -- make -C src look OUT=../out RECORDING=../in/take.mp4; then
  expect look "all done"
  check look-result test "$(cat "$work/out-l/still.png")" = still
  check look-no-lease bash -c 'test ! -s "$FAKE_CALLS"'
fi

# 5. detach, observe, re-attach
export FAKE_FRAMES=6 FAKE_FRAME_SLEEP=0.15
if run detach 0 run --job slow --no-wait --out "$work/out-s" \
  --progress 'out/frames/*.png:6' --pull 'out/macbook.mp4' --upload "$rec" "$comp" \
  -- make -C src render OUT=../out RECORDING=../in/take.mp4; then
  expect detach "re-attach any time: render-remote watch slow"
  run status-running 3 status slow || true
  expect status-running "running\|no status yet"
  run watch 0 watch slow || true
  expect watch "all done"
  check watch-result test -s "$work/out-s/macbook.mp4"
  run status-done 0 status slow || true
  expect status-done "done"
fi
unset FAKE_FRAMES FAKE_FRAME_SLEEP

# 6. a flaky network does not abandon the job; pull still works
run pull-missing 0 pull happy --out "$work/out-p" || true
check pull-copies test -s "$work/out-p/macbook.mp4"
export FAKE_SSH_DOWN=1
run unreachable 1 watch happy --out "$work/out-u" || true
expect unreachable "the job continues there"
unset FAKE_SSH_DOWN

# 7. argument errors
run no-args 2 || true
run bad-job 2 status "Not_Kebab" || true
run no-dir 2 run --job x || true
run no-cmd 2 run "$comp" || true
run bad-progress 2 run --progress nocolon "$comp" -- true || true
run duplicate-upload 1 run --job dup --upload "$rec" --upload "$work/other/take.mp4" "$comp" -- true || true

if ((fails)); then
  echo "$fails failure(s)"
  exit 1
fi
echo "render-remote: all tests passed"
