# Client for render-remote: rsync a directory (plus extra files) to the render
# host, run one command there detached under render-worker, show progress, and
# pull the finished outputs back. Expects RENDER_REMOTE_HOST and
# RENDER_REMOTE_ROOT from the Nix wrapper.
#
# The tool knows nothing about Blender or a particular composition: the caller
# supplies the command, the progress glob, and the output globs.
#
# This reaches another machine over ssh and rsync. Run it only when the user
# asked for it in the current turn.

HOST=${RENDER_REMOTE_HOST:?RENDER_REMOTE_HOST is not set}
ROOT=${RENDER_REMOTE_ROOT:?RENDER_REMOTE_ROOT is not set}
POLL=${RENDER_REMOTE_POLL:-10}
MAX_UNREACHABLE=${RENDER_REMOTE_MAX_UNREACHABLE:-30}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/render-remote

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=20)
RSYNC=(rsync -a -s --partial -e "ssh -o BatchMode=yes -o ConnectTimeout=20")

usage() {
  cat <<'EOF'
usage:
  render-remote run [--job ID] [--out DIR] [--gpu] [--no-wait]
                    [--progress GLOB:TOTAL] [--pull GLOB]... [--upload FILE]...
                    DIR -- CMD ARGS...
  render-remote watch  JOB [--out DIR]    re-attach: show progress, pull as files finish
  render-remote status JOB                one-shot summary
  render-remote pull   JOB [--out DIR]    fetch finished files, do not wait

  run       syncs DIR to the render host, uploads extra FILEs to in/, then runs
            CMD in the job directory. CMD sees DIR as ./src and uploaded files
            as ./in/<basename>. Use OUT=../out to write into the job's out/.
  --progress count matches of GLOB toward TOTAL (e.g. 'out/frames/*.png:180').
  --pull    a glob relative to the job dir; its matches are copied back by
            basename into --out (default: <dir of DIR>/rendered).
  --upload  an extra local file, available to CMD as in/<basename>.
  --gpu     wrap CMD in gpu-lease -- xvfb-run -a on the host.
  --job     lowercase kebab-case id (default: basename of DIR plus a stamp).
            Reuse an id to resume a finished job.

exit: 0 all done and pulled, 1 failed, 2 usage, 3 status: still running
The job keeps running on the host if this command or the laptop stops.
Env: RENDER_REMOTE_HOST, RENDER_REMOTE_ROOT, RENDER_REMOTE_POLL (seconds).
EOF
}

die() {
  printf 'render-remote: %s\n' "$*" >&2
  exit 1
}

usage_error() {
  printf 'render-remote: %s\n' "$*" >&2
  exit 2
}

valid_job() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]] || usage_error "job must be lowercase kebab-case: $1"
}

[[ "$ROOT" =~ ^[A-Za-z0-9._/-]+$ ]] || die "RENDER_REMOTE_ROOT has unsafe characters: $ROOT"

# --- remote state ----------------------------------------------------------

# Sets ALIVE, EXIT_CODE, STATUS_JSON and OUTPUTS_JSON. Returns 1 if unreachable.
# Exits if the job does not exist.
fetch_state() {
  local raw
  raw=$("${SSH[@]}" "$HOST" bash -s -- "$ROOT/$JOB" <<'EOF'
cd "$1" 2>/dev/null || { echo nojob; exit 0; }
if [ -f pid ] && kill -0 "$(cat pid)" 2>/dev/null; then echo alive=1; else echo alive=0; fi
if [ -f exitcode ]; then echo "exit=$(cat exitcode)"; else echo exit=none; fi
echo ---
cat status.json 2>/dev/null || true
echo ---
cat outputs.json 2>/dev/null || true
EOF
  ) || return 1
  [[ "$raw" != nojob* ]] || die "no job '$JOB' on $HOST under $ROOT"
  ALIVE=$(sed -n '/^alive=/{s///p;q}' <<<"$raw")
  EXIT_CODE=$(sed -n '/^exit=/{s///p;q}' <<<"$raw")
  STATUS_JSON=$(sed -n '/^---$/,/^---$/p' <<<"$raw" | sed '1d;$d')
  OUTPUTS_JSON=$(sed '1,/^---$/d' <<<"$raw" | sed '1,/^---$/d')
  [[ -n "$OUTPUTS_JSON" ]] || OUTPUTS_JSON='[]'
  return 0
}

remote_log_tail() {
  "${SSH[@]}" "$HOST" "tail -n 15 '$ROOT/$JOB/run.log' 2>/dev/null" || true
}

# Copy produced files that are not here yet. Sets PULLED to the number copied.
pull_ready() {
  local path name
  PULLED=0
  [[ -n "$OUTPUTS_JSON" ]] || return 0
  mkdir -p "$OUT_DIR"
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ "$path" != /* && "$path" != *..* ]] || die "unsafe output path from host: $path"
    name=$(basename -- "$path")
    [[ -s "$OUT_DIR/$name" ]] && continue
    "${RSYNC[@]}" "$HOST:$ROOT/$JOB/$path" "$OUT_DIR/" || return 1
    echo "pulled $name"
    PULLED=$((PULLED + 1))
  done < <(jq -r '.[]' <<<"$OUTPUTS_JSON")
}

summary_line() {
  jq -r '
    . as $s
    | "\($s.state)"
      + (if $s.progress_total then
           " \($s.progress_done // 0)/\($s.progress_total)"
           + (if $s.progress_total > 0
                then " (\((100 * ($s.progress_done // 0) / $s.progress_total | floor))%)"
                else "" end)
         else "" end)
  ' <<<"$STATUS_JSON"
}

failure_report() {
  jq -r '.error // "no error in status"' <<<"$STATUS_JSON" >&2
}

remember_out() {
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$OUT_DIR" >"$STATE_DIR/$JOB.out"
}

resolve_out() {
  if [[ -z "${OUT_DIR:-}" ]]; then
    [[ -f "$STATE_DIR/$JOB.out" ]] && OUT_DIR=$(<"$STATE_DIR/$JOB.out") || OUT_DIR=./rendered
  fi
  return 0
}

# --- commands --------------------------------------------------------------

watch_job() {
  local last="" unreachable=0 line state
  trap 'echo; echo "stopped watching; job $JOB keeps running on $HOST. Re-attach: render-remote watch $JOB"; exit 130' INT
  while true; do
    if ! fetch_state; then
      unreachable=$((unreachable + 1))
      ((unreachable <= MAX_UNREACHABLE)) || die "cannot reach $HOST (tried $unreachable times); the job continues there. Re-attach: render-remote watch $JOB"
      echo "cannot reach $HOST ($unreachable/$MAX_UNREACHABLE); retrying" >&2
      sleep "$POLL"
      continue
    fi
    unreachable=0
    pull_ready || die "copying a result from $HOST failed; rerun: render-remote pull $JOB"

    state=""
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
    if [[ "$state" == failed ]]; then
      failure_report
      die "job failed; finished files were copied to $OUT_DIR. Fix and rerun with: --job $JOB"
    fi
    if [[ "$ALIVE" == 0 ]]; then
      echo "job process is gone ($HOST:$ROOT/$JOB, exit=$EXIT_CODE); last log lines:" >&2
      remote_log_tail >&2
      die "job ended without finishing; rerun with --job $JOB to resume"
    fi
    sleep "$POLL"
  done
}

cmd_run() {
  local JOB="" OUT_DIR="" progress="" gpu=0 no_wait=0
  local uploads=() pulls=() dir="" cmd=()
  while (($#)); do
    case "$1" in
      --job) JOB=${2:?--job needs a value}; shift 2 ;;
      --out) OUT_DIR=${2:?--out needs a directory}; shift 2 ;;
      --progress) progress=${2:?--progress needs GLOB:TOTAL}; shift 2 ;;
      --pull) pulls+=("${2:?--pull needs a glob}"); shift 2 ;;
      --upload) uploads+=("${2:?--upload needs a file}"); shift 2 ;;
      --gpu) gpu=1; shift ;;
      --no-wait) no_wait=1; shift ;;
      -h | --help) usage; exit 0 ;;
      --)
        shift
        cmd=("$@")
        break
        ;;
      -*) usage_error "unknown option: $1" ;;
      *)
        [[ -z "$dir" ]] || usage_error "only one DIR is accepted: $1"
        dir=$1
        shift
        ;;
    esac
  done
  [[ -n "$dir" ]] || usage_error "no DIR given"
  [[ -d "$dir" ]] || die "not a directory: $dir"
  ((${#cmd[@]})) || usage_error "no command after --"
  [[ -z "$progress" || "$progress" == *:* ]] || usage_error "--progress must be GLOB:TOTAL"

  local seen file name
  for file in "${uploads[@]+"${uploads[@]}"}"; do
    [[ -f "$file" ]] || die "not a file: $file"
    name=$(basename -- "$file")
    for seen in "${uploads[@]+"${uploads[@]}"}"; do
      [[ "$seen" == "$file" ]] && continue
      [[ "$(basename -- "$seen")" != "$name" ]] || die "two uploads are named $name; rename one"
    done
  done

  if [[ -z "$JOB" ]]; then
    name=$(basename -- "$dir")
    JOB=$(tr -c 'a-z0-9\n' '-' <<<"${name,,}" | sed 's/--*/-/g; s/^-//; s/-$//')
    JOB=${JOB:-render}-$(date +%m%d-%H%M)
  fi
  valid_job "$JOB"
  [[ -n "$OUT_DIR" ]] || OUT_DIR=$(dirname -- "$dir")/rendered

  # A job whose named outputs are already local needs no work. Globs that can
  # match more than one file are left to watch/pull to resolve.
  local pull pending=0
  for pull in "${pulls[@]+"${pulls[@]}"}"; do
    name=$(basename -- "$pull")
    if [[ "$name" != *"*"* && -s "$OUT_DIR/$name" ]]; then
      echo "skip $name (already in $OUT_DIR)"
    else
      pending=1
    fi
  done
  if ((${#pulls[@]} == 0)); then pending=1; fi
  if ((pending == 0)); then
    echo "nothing to do: every result is already in $OUT_DIR"
    return 0
  fi
  remember_out

  # Preflight and job directory creation in one round trip.
  local pre
  pre=$("${SSH[@]}" "$HOST" bash -s -- "$ROOT/$JOB" <<'EOF'
set -e
mkdir -p "$1/src" "$1/out" "$1/in"
if command -v render-worker >/dev/null 2>&1; then echo worker=1; else echo worker=0; fi
tools=""
for t in make jq blender ffmpeg; do
  command -v "$t" >/dev/null 2>&1 && tools="$tools $t"
done
echo "tools:$tools"
if command -v xvfb-run >/dev/null 2>&1; then echo xvfb=1; else echo xvfb=0; fi
if command -v gpu-lease >/dev/null 2>&1; then echo lease=1; else echo lease=0; fi
if command -v setsid >/dev/null 2>&1; then echo setsid=1; else echo setsid=0; fi
if [ -f "$1/pid" ] && kill -0 "$(cat "$1/pid")" 2>/dev/null; then echo alive=1; else echo alive=0; fi
EOF
  ) || die "cannot reach $HOST over ssh"
  local worker tools xvfb lease setsid_ok alive
  worker=$(sed -n '/^worker=/{s///p;q}' <<<"$pre")
  tools=$(sed -n '/^tools:/{s///p;q}' <<<"$pre")
  xvfb=$(sed -n '/^xvfb=/{s///p;q}' <<<"$pre")
  lease=$(sed -n '/^lease=/{s///p;q}' <<<"$pre")
  setsid_ok=$(sed -n '/^setsid=/{s///p;q}' <<<"$pre")
  alive=$(sed -n '/^alive=/{s///p;q}' <<<"$pre")
  [[ "$worker" == 1 ]] || die "render-worker on $HOST is missing. Rebuild $HOST from this config first; nothing was uploaded."
  [[ " $tools " == *" jq "* ]] || die "jq is missing on $HOST; nothing was uploaded."
  [[ "$setsid_ok" == 1 ]] || die "setsid is missing on $HOST; nothing was uploaded."
  for file in make blender ffmpeg; do
    [[ " $tools " == *" $file "* ]] || printf 'render-remote: warning: %s is missing on %s\n' "$file" "$HOST" >&2
  done
  if ((gpu)); then
    [[ "$xvfb" == 1 && "$lease" == 1 ]] || die "--gpu needs xvfb-run and gpu-lease on $HOST; nothing was uploaded."
  fi
  [[ "$alive" == 0 ]] || die "job $JOB is already running on $HOST; attach with: render-remote watch $JOB"

  echo "uploading $dir to $HOST:$ROOT/$JOB/src/"
  "${RSYNC[@]}" --exclude 'out/' --exclude '.git/' -- "$dir/" "$HOST:$ROOT/$JOB/src/" || die "upload failed"
  if ((${#uploads[@]})); then
    echo "uploading ${#uploads[@]} extra file(s) to $HOST:$ROOT/$JOB/in/"
    "${RSYNC[@]}" -- "${uploads[@]}" "$HOST:$ROOT/$JOB/in/" || die "upload of extra files failed"
  fi

  # Written over stdin so arguments never pass through a remote shell string.
  local args=(render-worker)
  [[ -z "$progress" ]] || args+=(--progress "$progress")
  for pull in "${pulls[@]+"${pulls[@]}"}"; do args+=(--pull "$pull"); done
  ((gpu == 0)) || args+=(--gpu)
  args+=(-- "${cmd[@]}")
  {
    echo '#!/usr/bin/env bash'
    # shellcheck disable=SC2016 # expands on the server, not here
    echo 'cd "$(dirname "$0")" || exit 1'
    printf '%q ' "${args[@]}"
    echo
    echo 'echo $? > exitcode'
  } | "${SSH[@]}" "$HOST" "cat > '$ROOT/$JOB/run.sh'"

  "${SSH[@]}" "$HOST" bash -s -- "$ROOT/$JOB" <<'EOF' || die "could not start the job on $HOST"
cd "$1" || exit 1
rm -f exitcode status.json outputs.json pid
nohup setsid bash run.sh >run.log 2>&1 </dev/null &
echo $! >pid
EOF
  echo "started job $JOB on $HOST"
  echo "re-attach any time: render-remote watch $JOB"
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
  jq -r '.state | "  state\t\(.)"' <<<"$STATUS_JSON"
  case "$(jq -r .state <<<"$STATUS_JSON")" in
    "done") exit 0 ;;
    failed) failure_report; exit 1 ;;
    *) [[ "$ALIVE" == 1 ]] && exit 3
       echo "process is gone without finishing (exit=$EXIT_CODE)" >&2
       exit 1 ;;
  esac
}

subcommand=${1:-}
shift || true
case "$subcommand" in
  run) cmd_run "$@" ;;
  watch) cmd_watch "$@" ;;
  pull) cmd_pull "$@" ;;
  status) cmd_status "$@" ;;
  -h | --help | help) usage ;;
  *) usage >&2; exit 2 ;;
esac
