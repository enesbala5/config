# Client for upscaling on the GPU host: rsync up, run upscale-video detached
# under gpu-lease, show progress, rsync each finished file back as it lands.
# Expects UPSCALE_REMOTE_HOST and UPSCALE_REMOTE_ROOT (set by the Nix wrapper).
#
# This reaches another machine over ssh and rsync. Run it only when the user
# asked for it in the current turn.

HOST=${UPSCALE_REMOTE_HOST:?UPSCALE_REMOTE_HOST is not set}
ROOT=${UPSCALE_REMOTE_ROOT:?UPSCALE_REMOTE_ROOT is not set}
POLL=${UPSCALE_REMOTE_POLL:-10}
MAX_UNREACHABLE=${UPSCALE_REMOTE_MAX_UNREACHABLE:-30}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/upscale-remote

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=20)
RSYNC=(rsync -a -s --partial -e "ssh -o BatchMode=yes -o ConnectTimeout=20")

usage() {
  cat <<'EOF'
usage:
  upscale-remote run [--profile NAME] [--job ID] [--out DIR] [--no-wait] FILE...
  upscale-remote watch  JOB [--out DIR]    re-attach: show progress, pull as files finish
  upscale-remote status JOB                one-shot summary
  upscale-remote pull   JOB [--out DIR]    fetch finished files, do not wait

  run       copies FILE... to the server, starts one batch under gpu-lease and
            watches it. Files whose <name>.mp4 is already in the output
            directory are left out, so rerunning resumes.
  --job     lowercase kebab-case id (default: first file's name plus a stamp).
            Reuse an id to resume that job.
  --out     where results go (default: <dir of first FILE>/upscaled; remembered
            per job for watch and pull).
  --profile passed through to upscale-video; the server validates it.

exit: 0 all done and pulled, 1 failed, 2 usage, 3 status: still running
The job keeps running on the server if this command or the laptop stops.
Env: UPSCALE_REMOTE_HOST, UPSCALE_REMOTE_ROOT, UPSCALE_REMOTE_POLL (seconds).
EOF
}

die() {
  printf 'upscale-remote: %s\n' "$*" >&2
  exit 1
}

usage_error() {
  printf 'upscale-remote: %s\n' "$*" >&2
  exit 2
}

valid_job() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]] || usage_error "job must be lowercase kebab-case: $1"
}

[[ "$ROOT" =~ ^[A-Za-z0-9._/-]+$ ]] || die "UPSCALE_REMOTE_ROOT has unsafe characters: $ROOT"

# --- remote state ----------------------------------------------------------

# Sets ALIVE, EXIT_CODE and STATUS_JSON from the server. Returns 1 if the host
# cannot be reached. Exits if the job does not exist.
fetch_state() {
  local raw
  raw=$("${SSH[@]}" "$HOST" bash -s -- "$ROOT/$JOB" <<'EOF'
cd "$1" 2>/dev/null || { echo nojob; exit 0; }
if [ -f pid ] && kill -0 "$(cat pid)" 2>/dev/null; then echo alive=1; else echo alive=0; fi
if [ -f exitcode ]; then echo "exit=$(cat exitcode)"; else echo exit=none; fi
echo ---
cat status.json 2>/dev/null || true
EOF
  ) || return 1
  [[ "$raw" != nojob* ]] || die "no job '$JOB' on $HOST under $ROOT"
  ALIVE=$(sed -n '/^alive=/{s///p;q}' <<<"$raw")
  EXIT_CODE=$(sed -n '/^exit=/{s///p;q}' <<<"$raw")
  STATUS_JSON=$(sed '1,/^---$/d' <<<"$raw")
  return 0
}

remote_log_tail() {
  "${SSH[@]}" "$HOST" "tail -n 15 '$ROOT/$JOB/run.log' 2>/dev/null" || true
}

# Copy finished outputs that are not here yet. Sets PULLED to the number copied.
pull_ready() {
  local name
  PULLED=0
  [[ -n "$STATUS_JSON" ]] || return 0
  mkdir -p "$OUT_DIR"
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    [[ -s "$OUT_DIR/$name" ]] && continue
    "${RSYNC[@]}" "$HOST:$ROOT/$JOB/out/$name" "$OUT_DIR/" || return 1
    echo "pulled $name"
    PULLED=$((PULLED + 1))
  done < <(jq -r '.files[] | select(.state == "done" or .state == "skipped")
                  | .output | split("/") | last' <<<"$STATUS_JSON")
}

summary_line() {
  jq -r '
    .files as $f
    | ([$f[] | select(.state == "done" or .state == "skipped")] | length) as $done
    | ([$f[] | select(.state == "running")] | first) as $run
    | "\($done)/\($f | length) done"
      + (if $run then
           ", running \($run.name)"
           + (if $run.frames_total then
                " \($run.frames)/\($run.frames_total) frames (\(100 * $run.frames / $run.frames_total | floor)%)"
              else " \($run.frames) frames" end)
         else "" end)
  ' <<<"$STATUS_JSON"
}

failure_report() {
  jq -r '.files[] | select(.state == "failed") | "failed: \(.name): \(.error)"' <<<"$STATUS_JSON" >&2
}

remember_out() {
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$OUT_DIR" >"$STATE_DIR/$JOB.out"
}

resolve_out() {
  if [[ -z "${OUT_DIR:-}" ]]; then
    [[ -f "$STATE_DIR/$JOB.out" ]] && OUT_DIR=$(<"$STATE_DIR/$JOB.out") || OUT_DIR=./upscaled
  fi
  return 0
}

# --- commands --------------------------------------------------------------

watch_job() {
  local last="" unreachable=0 line
  trap 'echo; echo "stopped watching; job $JOB keeps running on $HOST. Re-attach: upscale-remote watch $JOB"; exit 130' INT
  while true; do
    if ! fetch_state; then
      unreachable=$((unreachable + 1))
      ((unreachable <= MAX_UNREACHABLE)) || die "cannot reach $HOST (tried $unreachable times); the job continues there. Re-attach: upscale-remote watch $JOB"
      echo "cannot reach $HOST ($unreachable/$MAX_UNREACHABLE); retrying" >&2
      sleep "$POLL"
      continue
    fi
    unreachable=0
    pull_ready || die "copying a result from $HOST failed; rerun: upscale-remote pull $JOB"

    local state=""
    [[ -z "$STATUS_JSON" ]] || state=$(jq -r .state <<<"$STATUS_JSON")
    if [[ -n "$STATUS_JSON" ]]; then
      line=$(summary_line)
      if [[ "$line" != "$last" ]]; then
        printf '%s %s\n' "$(date +%T)" "$line"
        last=$line
      fi
    fi

    if [[ "$state" == "done" ]]; then
      echo "all done; results in $OUT_DIR"
      return 0
    fi
    if [[ "$state" == "failed" ]]; then
      failure_report
      die "batch failed; finished files were copied to $OUT_DIR. Fix and rerun with: --job $JOB"
    fi
    if [[ "$ALIVE" == 0 ]]; then
      echo "batch process is gone ($HOST:$ROOT/$JOB, exit=$EXIT_CODE); last log lines:" >&2
      remote_log_tail >&2
      die "batch ended without finishing; rerun with --job $JOB to resume"
    fi
    sleep "$POLL"
  done
}

cmd_run() {
  local profile="" no_wait=0 files=() pending=() names=() stem name file seen
  JOB="" OUT_DIR=""
  while (($#)); do
    case "$1" in
      --profile) profile=${2:?--profile needs a value}; shift 2 ;;
      --job) JOB=${2:?--job needs a value}; shift 2 ;;
      --out) OUT_DIR=${2:?--out needs a directory}; shift 2 ;;
      --no-wait) no_wait=1; shift ;;
      -h | --help) usage; exit 0 ;;
      --) shift; files+=("$@"); break ;;
      -*) usage_error "unknown option: $1" ;;
      *) files+=("$1"); shift ;;
    esac
  done
  ((${#files[@]})) || usage_error "no input files"
  for file in "${files[@]}"; do
    [[ -f "$file" ]] || die "not a file: $file"
  done
  if [[ -z "$JOB" ]]; then
    stem=$(basename -- "${files[0]}")
    stem=${stem%.*}
    JOB=$(tr -c 'a-z0-9\n' '-' <<<"${stem,,}" | sed 's/--*/-/g; s/^-//; s/-$//')
    JOB=${JOB:-batch}-$(date +%m%d-%H%M)
  fi
  valid_job "$JOB"
  [[ -n "$OUT_DIR" ]] || OUT_DIR=$(dirname -- "${files[0]}")/upscaled

  for file in "${files[@]}"; do
    name=$(basename -- "$file")
    for seen in "${names[@]+"${names[@]}"}"; do
      [[ "$seen" != "$name" ]] || die "two inputs are named $name; rename one"
    done
    names+=("$name")
    stem=${name%.*}
    if [[ -s "$OUT_DIR/$stem.mp4" ]]; then
      echo "skip $name (already in $OUT_DIR)"
    else
      pending+=("$file")
    fi
  done
  if ((${#pending[@]} == 0)); then
    echo "nothing to do: every result is already in $OUT_DIR"
    return 0
  fi
  remember_out

  # Preflight, and make the job directory, in one round trip.
  local pre recovery alive
  pre=$("${SSH[@]}" "$HOST" bash -s -- "$ROOT/$JOB" <<'EOF'
mkdir -p "$1/in" "$1/out"
echo "recovery=$(cat /sys/module/amdgpu/parameters/gpu_recovery 2>/dev/null)"
if [ -f "$1/pid" ] && kill -0 "$(cat "$1/pid")" 2>/dev/null; then echo alive=1; else echo alive=0; fi
EOF
  ) || die "cannot reach $HOST over ssh"
  recovery=$(sed -n '/^recovery=/{s///p;q}' <<<"$pre")
  alive=$(sed -n '/^alive=/{s///p;q}' <<<"$pre")
  if [[ "$recovery" != 1 ]]; then
    echo "$HOST amdgpu.gpu_recovery is '${recovery}', not 1." >&2
    echo "The running kernel will not reset a stuck RX 570. Reboot into the generation that sets amdgpu.gpu_recovery=1, then run this again." >&2
    exit 1
  fi
  [[ "$alive" == 0 ]] || die "job $JOB is already running on $HOST; attach with: upscale-remote watch $JOB"

  echo "uploading ${#pending[@]} file(s) to $HOST:$ROOT/$JOB/in/"
  "${RSYNC[@]}" -- "${pending[@]}" "$HOST:$ROOT/$JOB/in/" || die "upload failed"

  # run.sh is written through stdin, so file names never pass through a remote
  # shell command line.
  local upscale=(gpu-lease -- upscale-video)
  [[ -z "$profile" ]] || upscale+=(--profile "$profile")
  upscale+=(--out-dir out --status-file status.json --)
  for file in "${pending[@]}"; do
    upscale+=("in/$(basename -- "$file")")
  done
  {
    echo '#!/usr/bin/env bash'
    # shellcheck disable=SC2016 # expands on the server, not here
    echo 'cd "$(dirname "$0")" || exit 1'
    printf '%q ' "${upscale[@]}"
    echo
    echo 'echo $? > exitcode'
  } | "${SSH[@]}" "$HOST" "cat > '$ROOT/$JOB/run.sh'"

  "${SSH[@]}" "$HOST" bash -s -- "$ROOT/$JOB" <<'EOF' || die "could not start the batch on $HOST"
cd "$1" || exit 1
rm -f exitcode status.json pid
nohup setsid bash run.sh >run.log 2>&1 </dev/null &
echo $! >pid
EOF
  echo "started job $JOB on $HOST (gpu-lease: the local LLM endpoint is down until it ends)"
  echo "re-attach any time: upscale-remote watch $JOB"
  ((no_wait == 0)) || return 0
  watch_job
}

cmd_watch() {
  JOB=${1:-}; shift || true
  OUT_DIR=""
  while (($#)); do
    case "$1" in
      --out) OUT_DIR=${2:?--out needs a directory}; shift 2 ;;
      *) usage_error "unknown option: $1" ;;
    esac
  done
  [[ -n "$JOB" ]] || usage_error "watch needs a job id"
  valid_job "$JOB"
  resolve_out
  watch_job
}

cmd_pull() {
  JOB=${1:-}; shift || true
  OUT_DIR=""
  while (($#)); do
    case "$1" in
      --out) OUT_DIR=${2:?--out needs a directory}; shift 2 ;;
      *) usage_error "unknown option: $1" ;;
    esac
  done
  [[ -n "$JOB" ]] || usage_error "pull needs a job id"
  valid_job "$JOB"
  resolve_out
  fetch_state || die "cannot reach $HOST over ssh"
  pull_ready || die "copying a result from $HOST failed"
  echo "pulled $PULLED file(s) into $OUT_DIR"
}

cmd_status() {
  JOB=${1:-}
  [[ -n "$JOB" ]] || usage_error "status needs a job id"
  valid_job "$JOB"
  fetch_state || die "cannot reach $HOST over ssh"
  if [[ -z "$STATUS_JSON" ]]; then
    echo "no status yet (process alive=$ALIVE exit=$EXIT_CODE)"
    [[ "$ALIVE" == 1 ]] && exit 3
    remote_log_tail >&2
    exit 1
  fi
  summary_line
  jq -r '.files[] | "  \(.state)\t\(.name)"' <<<"$STATUS_JSON"
  case "$(jq -r .state <<<"$STATUS_JSON")" in
    done) exit 0 ;;
    failed) failure_report; exit 1 ;;
    *) [[ "$ALIVE" == 1 ]] && exit 3
       echo "process is gone without finishing (exit=$EXIT_CODE)" >&2
       exit 1 ;;
  esac
}

cmd=${1:-}
shift || true
case "$cmd" in
  run) cmd_run "$@" ;;
  watch) cmd_watch "$@" ;;
  pull) cmd_pull "$@" ;;
  status) cmd_status "$@" ;;
  -h | --help | help) usage ;;
  *) usage >&2; exit 2 ;;
esac
