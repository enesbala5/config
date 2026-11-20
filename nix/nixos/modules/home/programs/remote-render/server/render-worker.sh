# Server side of render-remote. Runs one command in the current directory
# (a job directory made by the client), keeps a machine-readable status.json,
# and lists the files produced by --pull globs in outputs.json.
#
# usage: render-worker [--progress GLOB:TOTAL] [--pull GLOB]... [--gpu] -- CMD ARGS...
#
# RENDER_WORKER_POLL (from the Nix wrapper) controls status update frequency.
# This runs on the render host, reached only through ssh by render-remote.

set -euo pipefail

usage() {
  cat <<'EOF'
usage: render-worker [--progress GLOB:TOTAL] [--pull GLOB]... [--gpu] -- CMD ARGS...

  Runs CMD in the current directory, reporting state in status.json and the
  paths matching --pull in outputs.json once CMD exits 0.
  --gpu wraps CMD in 'gpu-lease -- xvfb-run -a' for headless GPU rendering.

Environment: RENDER_WORKER_POLL (status interval, seconds).
EOF
}

die() {
  printf 'render-worker: %s\n' "$*" >&2
  exit 1
}

usage_error() {
  printf 'render-worker: %s\n' "$*" >&2
  exit 2
}

POLL=${RENDER_WORKER_POLL:-3}
progress_glob="" progress_total=0
pulls=()
gpu=0

while (($#)); do
  case "$1" in
    --progress)
      spec=${2:?--progress needs GLOB:TOTAL}
      shift 2
      [[ "$spec" == *:* ]] || usage_error "--progress must be GLOB:TOTAL: $spec"
      progress_glob=${spec%:*}
      progress_total=${spec##*:}
      [[ "$progress_total" =~ ^[0-9]+$ ]] || usage_error "--progress total must be an integer: $progress_total"
      ;;
    --pull) pulls+=("${2:?--pull needs a glob}"); shift 2 ;;
    --gpu) gpu=1; shift ;;
    -h | --help) usage; exit 0 ;;
    --) shift; break ;;
    *) usage_error "unknown option: $1" ;;
  esac
done
(($#)) || usage_error "no command after --"
cmd=("$@")

[[ -n "$progress_glob" || "$progress_total" -eq 0 ]] || usage_error "--progress needs both a glob and a total"

if ((gpu)); then
  command -v gpu-lease >/dev/null 2>&1 || die "gpu-lease is not on PATH"
  command -v xvfb-run >/dev/null 2>&1 || die "xvfb-run is not on PATH"
fi

STATUS=status.json
OUTPUTS=outputs.json

# Globs are restricted to a fixed directory with a wildcard in the last
# component, e.g. out/frames/*.png. Nix's bash has no compgen, so find does the
# expansion. A pattern with no matches yields zero, never a literal path.
glob_matches() {
  local glob=$1 dir pattern
  dir=${glob%/*}
  pattern=${glob##*/}
  [[ "$dir" != "$glob" ]] || dir=.
  [[ -n "$pattern" ]] || pattern='*'
  [[ -d "$dir" ]] || return 0
  find "$dir" -maxdepth 1 -type f -name "$pattern" -print | sed 's#^\./##'
}

count_progress() {
  [[ -n "$progress_glob" ]] || { echo 0; return; }
  glob_matches "$progress_glob" | wc -l | tr -d ' '
}

write_status() {
  local state=$1 progress_done=$2 error=$3
  [[ -f started_at ]] || date -u +%Y-%m-%dT%H:%M:%SZ >started_at
  local started
  started=$(<started_at)
  jq -n \
    --arg state "$state" \
    --arg started "$started" \
    --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson progress_done "$progress_done" \
    --argjson total "$progress_total" \
    --arg error "$error" \
    --argjson has_progress "$([[ -n "$progress_glob" ]] && echo true || echo false)" \
    '{
      version: 1,
      state: $state,
      started_at: $started,
      updated_at: $now
    }
    + (if $has_progress then {progress_done: $progress_done, progress_total: $total} else {} end)
    + (if $error != "" then {error: $error} else {} end)' \
    >"$STATUS.tmp"
  mv "$STATUS.tmp" "$STATUS"
}

write_outputs() {
  local out=() glob match
  for glob in "${pulls[@]}"; do
    while IFS= read -r match; do
      [[ -n "$match" ]] && out+=("$match")
    done < <(glob_matches "$glob")
  done
  printf '%s\n' "${out[@]}" | jq -R 'select(length > 0)' | jq -s . >"$OUTPUTS.tmp"
  mv "$OUTPUTS.tmp" "$OUTPUTS"
}

watch_progress() {
  local pid=$1
  while kill -0 "$pid" 2>/dev/null; do
    write_status running "$(count_progress)" ""
    sleep "$POLL"
  done
}

rm -f "$STATUS" "$OUTPUTS" exitcode started_at
write_status queued 0 ""

if ((gpu)); then
  wrapped=(gpu-lease -- xvfb-run -a "${cmd[@]}")
else
  wrapped=("${cmd[@]}")
fi

"${wrapped[@]}" &
pid=$!
watch_progress "$pid" &
watch_pid=$!

set +e
wait "$pid"
code=$?
set -e

kill "$watch_pid" 2>/dev/null || true
wait "$watch_pid" 2>/dev/null || true
echo "$code" >exitcode

if ((code == 0)); then
  write_outputs
  write_status "done" "$(count_progress)" ""
else
  error=$(tail -n 15 run.log 2>/dev/null | tr '\n' ' ' | cut -c1-400)
  write_status failed "$(count_progress)" "$error"
fi

exit "$code"
