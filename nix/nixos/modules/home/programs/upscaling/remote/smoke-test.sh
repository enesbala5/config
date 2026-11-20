#!/usr/bin/env bash
# End-to-end check of upscale-remote against the real GPU host.
#
#   bash smoke-test.sh [--keep]
#
# Runs ssh and rsync against $UPSCALE_REMOTE_HOST (default home-server) and stops
# llama-cpp there while batches run. Only run it when you mean to.
# Makes 8-frame clips (one model chunk, about 3 minutes each on the RX 570) from
# SMOKE_SRC, then: preflight, a 2-clip batch, a detach/re-attach run, a resume, a real failure, output check, and cleanup.
# Exits non-zero if any check fails. --keep leaves the local and remote files.

set -uo pipefail

host=${UPSCALE_REMOTE_HOST:-home-server}
src=${SMOKE_SRC:-/home/e/dev/coverlttr/misc/video/hyperframes/projects/ugc/maya-actually-cared-fast-1080p/assets/ai/higgsfield-long-cut/silent/01-problem.mp4}
keep=0
[[ "${1:-}" == --keep ]] && keep=1

stamp=$(date +%H%M%S)
work=$(mktemp -d -t upscale-smoke.XXXXXX)
fails=0
finished=0

step() { printf '\n=== %s (t+%ss)\n' "$*" "$SECONDS"; }
pass() { printf 'PASS %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; fails=$((fails + 1)); }
check() { # check <label> <command...>
  local label=$1
  shift
  if "$@"; then pass "$label"; else fail "$label"; fi
}

cleanup() {
  # An interrupted run may leave a batch running on the server: do not pull its
  # directory out from under it.
  ((finished)) || keep=1
  if ((keep)); then
    echo "kept: $work and $host:~/upscale-jobs/smoke-$stamp-*"
    return
  fi
  ssh -o BatchMode=yes "$host" "rm -rf ~/upscale-jobs/smoke-$stamp-*" || true
  rm -rf "$work" "$HOME/.local/state/upscale-remote"/smoke-"$stamp"-*.out
}
trap cleanup EXIT

[[ -f "$src" ]] || { echo "source clip not found: $src (set SMOKE_SRC)"; exit 2; }
cd "$work"

step "1. local: make test clips"
for n in a b c; do
  ffmpeg -v error -y -i "$src" -frames:v 8 -an -c:v libx264 -pix_fmt yuv420p "clip-$n.mp4"
done
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate \
  -of default=nw=1 clip-a.mp4
check "upscale-remote is installed" command -v upscale-remote

step "2. server: tools on PATH for a non-interactive ssh, GPU recovery on"
ssh -o BatchMode=yes "$host" 'command -v upscale-video gpu-lease; echo "gpu_recovery=$(cat /sys/module/amdgpu/parameters/gpu_recovery)"; upscale-video --help | grep -E "out-dir|status-file"' \
  | tee pre.txt
check "upscale-video found" grep -q upscale-video pre.txt
check "gpu-lease found" grep -q gpu-lease pre.txt
check "gpu_recovery=1" grep -q 'gpu_recovery=1' pre.txt
check "server has batch flags" grep -q -- '--out-dir' pre.txt

step "3. batch of two clips: progress and pull"
job1=smoke-$stamp-1
upscale-remote run --job "$job1" --out "$work/out1" clip-a.mp4 clip-b.mp4
check "batch exit 0" test $? -eq 0
check "clip-a pulled" test -s "$work/out1/clip-a.mp4"
check "clip-b pulled" test -s "$work/out1/clip-b.mp4"

step "4. detach, then re-attach"
job2=smoke-$stamp-2
upscale-remote run --job "$job2" --no-wait --out "$work/out2" clip-c.mp4
check "started detached" test $? -eq 0
upscale-remote status "$job2"
code=$?
echo "status exit=$code (3 = running, 0 = already done)"
check "status says running or done" test "$code" -eq 3 -o "$code" -eq 0
upscale-remote watch "$job2"
check "watch exit 0" test $? -eq 0
check "clip-c pulled" test -s "$work/out2/clip-c.mp4"
upscale-remote status "$job2"
check "status done exit 0" test $? -eq 0

step "5. resume: nothing to do"
upscale-remote run --job "$job1" --out "$work/out1" clip-a.mp4 clip-b.mp4 | tee resume.txt
check "resume skips everything" grep -q "nothing to do" resume.txt

step "6. real failure: not a video"
echo not-a-video >bad.mp4
job3=smoke-$stamp-3
upscale-remote run --job "$job3" --out "$work/out3" bad.mp4 2>&1 | tee bad.txt
check "failure reported" grep -q "failed: bad.mp4" bad.txt
check "no output for bad.mp4" test ! -e "$work/out3/bad.mp4"

step "7. output and llama-cpp"
src_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 clip-a.mp4)
out_info=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$work/out1/clip-a.mp4")
echo "output: $out_info (source fps $src_fps)"
check "output is 1080p" grep -Eq '^(1920,1080|1080,1920),' <<<"$out_info"
check "frame rate unchanged" grep -q ",$src_fps\$" <<<"$out_info"
state=$(ssh -o BatchMode=yes "$host" 'systemctl is-active llama-cpp.service' 2>&1 || true)
echo "llama-cpp: $state"
check "llama-cpp is active again" test "$state" = active
health=$(curl -fsS --max-time 10 "http://$host:8080/health" 2>&1 || true)
echo "health: $health"
check "llama health ok" grep -q '"ok"' <<<"$health"

step "done"
((fails)) || finished=1 # keep files for inspection when a check failed
if ((fails)); then
  echo "$fails check(s) FAILED"
  exit 1
fi
echo "all checks passed in ${SECONDS}s"
