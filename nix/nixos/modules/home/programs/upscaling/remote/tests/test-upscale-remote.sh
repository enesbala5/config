#!/usr/bin/env bash
# upscale-remote against a fake server. `ssh` runs the remote command locally in
# a scratch "remote home"; rsync is real and uses that ssh. Only upscale-video
# and gpu-lease are stand-ins. Needs bash, coreutils, sed, jq, rsync, util-linux.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script="$here/../upscale-remote.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export FAKE_REMOTE_HOME="$work/remote-home"
export HOME="$work/laptop-home"
export XDG_STATE_HOME="$work/state"
export UPSCALE_REMOTE_HOST=fakehost
export UPSCALE_REMOTE_ROOT=upscale-jobs
export UPSCALE_REMOTE_POLL=0.2
export UPSCALE_REMOTE_MAX_UNREACHABLE=3
export FAKE_RECOVERY_FILE="$work/gpu_recovery"
mkdir -p "$FAKE_REMOTE_HOME" "$HOME" "$work/bin" "$work/in"
echo 1 >"$FAKE_RECOVERY_FILE"

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
  sed "s#/sys/module/amdgpu/parameters/gpu_recovery#$FAKE_RECOVERY_FILE#" | bash -s -- "${@:4}"
else
  exec bash -c "$*"
fi
EOF

cat >"$work/bin/gpu-lease" <<'EOF'
#!/usr/bin/env bash
shift # --
exec "$@"
EOF

cat >"$work/bin/upscale-video" <<'EOF'
#!/usr/bin/env bash
# Same batch contract as the real tool: --out-dir, --status-file, resume, stop on failure.
out="" status="" inputs=()
while (($#)); do
  case "$1" in
    --out-dir) out=$2; shift 2 ;;
    --status-file) status=$2; shift 2 ;;
    --profile) shift 2 ;;
    --) shift; inputs=("$@"); break ;;
    *) exit 64 ;;
  esac
done
[[ -z "${FAKE_DIE:-}" ]] || { echo "boom" >&2; exit 7; }
mkdir -p "$out"
states=() errs=()
for _ in "${inputs[@]}"; do states+=(queued); errs+=(""); done
write() {
  local i name files=()
  for i in "${!inputs[@]}"; do
    name=$(basename -- "${inputs[$i]}")
    files+=("$(jq -n --arg name "$name" --arg out "$PWD/$out/${name%.*}.mp4" \
      --arg state "${states[$i]}" --arg err "${errs[$i]}" \
      '{name: $name, output: $out, state: $state, frames: 3, frames_total: 10}
       + (if $err != "" then {error: $err} else {} end)')")
  done
  printf '%s\n' "${files[@]}" | jq -s --arg state "$1" '{version: 1, state: $state, files: .}' >"$status.tmp"
  mv "$status.tmp" "$status"
}
write running
for i in "${!inputs[@]}"; do
  name=$(basename -- "${inputs[$i]}")
  dest="$out/${name%.*}.mp4"
  if [[ -s "$dest" ]]; then states[i]=skipped; write running; continue; fi
  states[i]=running; write running
  sleep "${FAKE_STEP:-0.3}"
  if [[ "$name" == "${FAKE_FAIL_ON:-}" ]]; then
    states[i]=failed; errs[i]="model exploded"; write failed
    echo "upscale-video: $name: model exploded" >&2
    exit 1
  fi
  cp "${inputs[$i]}" "$dest.partial" && mv "$dest.partial" "$dest"
  states[i]=done; write running
done
write done
EOF
# The Nix sandbox has no /usr/bin/env.
sed -i "1s|.*|#!$(command -v bash)|" "$work/bin/"*
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH"

# --- harness -----------------------------------------------------------------

fails=0
run() { # run <name> <expected exit> <args...>; output in $work/out.txt
  local name=$1 want=$2 got=0
  shift 2
  bash -euo pipefail "$script" "$@" >"$work/out.txt" 2>&1 || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "FAIL $name: exit $got, wanted $want"
    sed 's/^/    /' "$work/out.txt"
    fails=$((fails + 1))
    return 1
  fi
}
expect() { # expect <name> <pattern>   pattern must appear in the last output
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

printf 'clip-a' >"$work/in/a.mp4"
printf 'clip-b' >"$work/in/b with space.mp4"
out="$work/out"

# 1. happy path: upload, run, pull both
if run happy 0 run --job happy --out "$out" "$work/in/a.mp4" "$work/in/b with space.mp4"; then
  expect happy "all done"
  expect happy "pulled a.mp4"
  check happy-a test "$(cat "$out/a.mp4")" = clip-a
  check happy-b test "$(cat "$out/b with space.mp4")" = clip-b
  check happy-remote-in test -f "$FAKE_REMOTE_HOME/upscale-jobs/happy/in/a.mp4"
  check happy-state test -f "$XDG_STATE_HOME/upscale-remote/happy.out"
fi

# 2. rerun: everything is already local, nothing is uploaded or started
if run rerun 0 run --job happy --out "$out" "$work/in/a.mp4" "$work/in/b with space.mp4"; then
  expect rerun "nothing to do"
fi

# 3. preflight refuses when the kernel will not reset the GPU
echo 0 >"$FAKE_RECOVERY_FILE"
if run recovery 1 run --job norecover --out "$work/out-nr" "$work/in/a.mp4"; then
  expect recovery "gpu_recovery"
  check recovery-no-upload test ! -e "$FAKE_REMOTE_HOME/upscale-jobs/norecover/in/a.mp4"
fi
echo 1 >"$FAKE_RECOVERY_FILE"

# 4. failure mid-batch: finished file is pulled, failed one is named, exit 1
export FAKE_FAIL_ON="b with space.mp4"
if run failure 1 run --job flaky --out "$work/out-f" "$work/in/a.mp4" "$work/in/b with space.mp4"; then
  expect failure "failed: b with space.mp4: model exploded"
  check failure-a-pulled test -s "$work/out-f/a.mp4"
  check failure-b-absent test ! -e "$work/out-f/b with space.mp4"
fi
unset FAKE_FAIL_ON

# 5. resume the same job: only the missing file goes up and runs
if run resume 0 run --job flaky --out "$work/out-f" "$work/in/a.mp4" "$work/in/b with space.mp4"; then
  expect resume "skip a.mp4"
  check resume-b test "$(cat "$work/out-f/b with space.mp4")" = clip-b
fi

# 6. detach, observe, re-attach
export FAKE_STEP=0.6
if run detach 0 run --job slow --no-wait --out "$work/out-s" "$work/in/a.mp4"; then
  expect detach "re-attach any time: upscale-remote watch slow"
  run status-running 3 status slow || true
  expect status-running "running\|no status yet"
  run watch 0 watch slow || true
  expect watch "all done"
  check watch-a test -s "$work/out-s/a.mp4"
  run status-done 0 status slow || true
  expect status-done "1/1 done"
fi
unset FAKE_STEP

# 7. process dies before writing any status
export FAKE_DIE=1
if run died 1 run --job died --out "$work/out-d" "$work/in/a.mp4"; then
  :
fi
expect died "ended without finishing"
expect died "boom"
unset FAKE_DIE

# 8. a flaky network does not abandon the job; a dead one gives up with advice
run pull-missing 0 pull happy --out "$work/out-p" || true
check pull-copies test -s "$work/out-p/a.mp4"
export FAKE_SSH_DOWN=1
run unreachable 1 watch happy --out "$work/out-u" || true
expect unreachable "the job continues there"
unset FAKE_SSH_DOWN

# 9. argument errors
run no-args 2 || true
run bad-job 2 watch "Not_Kebab" || true
run bad-opt 2 run --bogus a || true
run no-files 2 run --job x || true

if ((fails)); then
  echo "$fails failure(s)"
  exit 1
fi
echo "upscale-remote: all tests passed"
