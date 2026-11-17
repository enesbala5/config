# Expects systemctl_bin and tool_path from the Nix wrapper.
# Invoked as: gpu-lease -- command [args...]
# Re-execs itself with sudo when unprivileged. The payload runs as SUDO_USER.

unit="llama-cpp.service"
vram_limit=$((1024 * 1024 * 1024))
wait_secs="${GPU_LEASE_VRAM_WAIT:-15}"
lock_path="${GPU_LEASE_LOCK:-/run/gpu-lease.lock}"
sysfs="${GPU_LEASE_SYSFS:-/sys/class/drm}"

usage() {
  echo "usage: gpu-lease -- command [args...]" >&2
  exit 2
}

user_path=""
if [[ "${1:-}" == "--user-path" ]]; then
  if [[ $# -lt 2 ]]; then
    usage
  fi
  user_path="$2"
  shift 2
fi

if [[ "${1:-}" != "--" ]]; then
  usage
fi
shift
if [[ $# -lt 1 ]]; then
  usage
fi

if [[ "${GPU_LEASE_TEST:-}" != 1 && "$(id -u)" -ne 0 ]]; then
  exec sudo -n -- "$0" --user-path "${PATH-}" -- "$@"
fi

export PATH="${tool_path}:${PATH-}"

if [[ "${GPU_LEASE_TEST:-}" != 1 ]]; then
  if [[ -z "${SUDO_USER:-}" ]]; then
    echo "gpu-lease: refusing to run the command as root" >&2
    exit 1
  fi
  if [[ -z "$user_path" ]]; then
    echo "gpu-lease: missing user PATH; run gpu-lease from your user, not a root shell" >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "$lock_path")"
exec 9>"$lock_path"
if ! flock -n 9; then
  echo "gpu-lease: another lease is running" >&2
  exit 1
fi

stopped=0

restore() {
  status=$?
  if [[ "$stopped" -eq 1 ]]; then
    if ! "$systemctl_bin" start "$unit"; then
      echo "gpu-lease: failed to start ${unit}. Recover with: sudo systemctl start ${unit}" >&2
      if [[ "$status" -eq 0 ]]; then
        status=1
      fi
    fi
  fi
  exit "$status"
}

trap restore EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if "$systemctl_bin" is-active --quiet "$unit"; then
  echo "gpu-lease: stopping ${unit} (in-flight /v1 requests will fail)" >&2
  stopped=1
  "$systemctl_bin" stop "$unit"
fi

wait_for_vram() {
  local deadline=$((SECONDS + wait_secs))
  local saw=0
  local max=0
  local n=0
  local reading
  while true; do
    saw=0
    max=0
    for reading in "${sysfs}"/card*/device/mem_info_vram_used; do
      saw=1
      [[ -r "$reading" ]] || continue
      n="$(<"$reading")"
      [[ "$n" =~ ^[0-9]+$ ]] || continue
      if (( n > max )); then
        max=$n
      fi
    done
    if [[ "$saw" -eq 0 ]]; then
      echo "gpu-lease: no VRAM sysfs under ${sysfs}; continuing" >&2
      return 0
    fi
    if (( max < vram_limit )); then
      return 0
    fi
    if (( SECONDS >= deadline )); then
      echo "gpu-lease: VRAM still ${max} bytes after ${wait_secs}s (limit ${vram_limit})" >&2
      return 1
    fi
    sleep 0.2
  done
}

wait_for_vram

if [[ "${GPU_LEASE_TEST:-}" == 1 ]]; then
  "$@"
else
  runuser -u "$SUDO_USER" -- env "PATH=${user_path}" "$@"
fi
