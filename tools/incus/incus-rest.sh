#!/usr/bin/env bash
# Incus REST helper over the local unix socket. Host scripts should source
# this instead of calling the `incus` CLI.
#
# Env:
#   INCUS_SOCKET   default: /var/lib/incus/unix.socket
#   INCUS_API      default: http://localhost (path-only; socket provides the daemon)
set -euo pipefail

INCUS_SOCKET="${INCUS_SOCKET:-/var/lib/incus/unix.socket}"
INCUS_API="${INCUS_API:-http://localhost}"

incus_api() {
  local method="$1"
  local path="$2"
  shift 2
  if [[ ! -S "$INCUS_SOCKET" ]]; then
    echo "Error: Incus unix socket not found at $INCUS_SOCKET" >&2
    return 1
  fi
  curl -sS --unix-socket "$INCUS_SOCKET" \
    -X "$method" \
    -H "Content-Type: application/json" \
    "${INCUS_API}${path}" \
    "$@"
}

incus_api_raw() {
  local method="$1"
  local path="$2"
  shift 2
  if [[ ! -S "$INCUS_SOCKET" ]]; then
    echo "Error: Incus unix socket not found at $INCUS_SOCKET" >&2
    return 1
  fi
  curl -sS --unix-socket "$INCUS_SOCKET" \
    -X "$method" \
    "${INCUS_API}${path}" \
    "$@"
}

incus_json_get() {
  local json="$1"
  local filter="$2"
  jq -r "$filter" <<<"$json"
}

incus_wait_operation() {
  local op_url="$1"
  local timeout="${2:-180}"
  if [[ -z "$op_url" || "$op_url" == "null" ]]; then
    return 0
  fi
  local result
  result="$(incus_api GET "${op_url}?wait=1&timeout=${timeout}")"
  local status
  status="$(incus_json_get "$result" '.metadata.status // .status // empty')"
  if [[ "$status" != "Success" ]]; then
    echo "Error: Incus operation failed ($status)" >&2
    echo "$result" | jq -C . >&2 || echo "$result" >&2
    return 1
  fi
  printf '%s' "$result"
}

incus_request() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local resp
  if [[ -n "$body" ]]; then
    resp="$(incus_api "$method" "$path" -d "$body")"
  else
    resp="$(incus_api "$method" "$path")"
  fi
  local code
  code="$(incus_json_get "$resp" '.status_code // 0')"
  case "$code" in
    100|200)
      printf '%s' "$resp"
      ;;
    103|202)
      local op
      op="$(incus_json_get "$resp" '.operation // .metadata.id // empty')"
      if [[ "$op" == /* ]]; then
        incus_wait_operation "$op"
      elif [[ -n "$op" && "$op" != "null" ]]; then
        incus_wait_operation "/1.0/operations/${op}"
      else
        printf '%s' "$resp"
      fi
      ;;
    *)
      echo "Error: Incus REST $method $path failed" >&2
      echo "$resp" | jq -C . >&2 || echo "$resp" >&2
      return 1
      ;;
  esac
}

incus_instance_exists() {
  local name="$1"
  local resp
  resp="$(incus_api GET "/1.0/instances/${name}" || true)"
  local code
  code="$(incus_json_get "$resp" '.error_code // .status_code // 0' 2>/dev/null || echo 0)"
  [[ "$code" == "200" ]]
}

incus_instance_status() {
  local name="$1"
  local resp
  resp="$(incus_api GET "/1.0/instances/${name}/state")"
  incus_json_get "$resp" '.metadata.status // empty'
}

incus_instance_create() {
  local name="$1"
  local image="${2:-ubuntu/24.04/cloud}"
  local profile="${3:-default}"
  local profiles_json
  if [[ "$profile" != "default" ]]; then
    profiles_json="$(jq -nc --arg d default --arg p "$profile" '[$d, $p]')"
  else
    profiles_json="$(jq -nc --arg p "$profile" '[$p]')"
  fi
  local body
  body="$(jq -nc \
    --arg name "$name" \
    --arg alias "$image" \
    --argjson profiles "$profiles_json" \
    '{
      name: $name,
      type: "virtual-machine",
      profiles: $profiles,
      source: {
        type: "image",
        protocol: "simplestreams",
        server: "https://images.linuxcontainers.org",
        alias: $alias
      }
    }')"
  incus_request POST "/1.0/instances" "$body" >/dev/null
}

incus_instance_start() {
  local name="$1"
  incus_request PUT "/1.0/instances/${name}/state" \
    '{"action":"start","timeout":120}' >/dev/null || true
}

incus_instance_stop() {
  local name="$1"
  incus_request PUT "/1.0/instances/${name}/state" \
    '{"action":"stop","timeout":120,"force":true}' >/dev/null || true
}

incus_instance_exec() {
  local name="$1"
  shift
  local cmd_json
  cmd_json="$(jq -nc --args '$ARGS.positional' -- "$@")"
  local body
  body="$(jq -nc --argjson command "$cmd_json" '{
    command: $command,
    "wait-for-websocket": false,
    interactive: false,
    "record-output": true
  }')"
  local result
  result="$(incus_request POST "/1.0/instances/${name}/exec" "$body")"
  local exit_code
  exit_code="$(incus_json_get "$result" '.metadata.metadata.return // .metadata.return // 0')"
  local stdout_log stderr_log
  stdout_log="$(incus_json_get "$result" '.metadata.metadata.output["1"] // empty')"
  stderr_log="$(incus_json_get "$result" '.metadata.metadata.output["2"] // empty')"
  if [[ -n "$stdout_log" && "$stdout_log" != "null" ]]; then
    incus_api_raw GET "$stdout_log" || true
  fi
  if [[ -n "$stderr_log" && "$stderr_log" != "null" ]]; then
    incus_api_raw GET "$stderr_log" >&2 || true
  fi
  return "$exit_code"
}

incus_file_push() {
  local name="$1"
  local src="$2"
  local dest="$3"
  local mode="${4:-0600}"
  local uid="${5:-0}"
  local gid="${6:-0}"
  if [[ ! -f "$src" ]]; then
    echo "Error: source file not found: $src" >&2
    return 1
  fi
  local encoded
  encoded="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$dest")"
  curl -sS --unix-socket "$INCUS_SOCKET" \
    -X POST \
    -H "X-Incus-uid: ${uid}" \
    -H "X-Incus-gid: ${gid}" \
    -H "X-Incus-mode: ${mode}" \
    -H "X-Incus-type: file" \
    --data-binary @"$src" \
    "${INCUS_API}/1.0/instances/${name}/files?path=${encoded}" >/dev/null
}

incus_file_pull() {
  local name="$1"
  local src="$2"
  local dest="$3"
  local encoded
  encoded="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$src")"
  mkdir -p "$(dirname "$dest")"
  curl -sS --unix-socket "$INCUS_SOCKET" \
    -o "$dest" \
    "${INCUS_API}/1.0/instances/${name}/files?path=${encoded}"
}

incus_dir_pull_tar() {
  local name="$1"
  local guest_dir="$2"
  local host_tar="$3"
  local tmp="/tmp/incus-rest-pull-$$.tar"
  incus_instance_exec "$name" tar -C "$(dirname "$guest_dir")" -cf "$tmp" "$(basename "$guest_dir")"
  incus_file_pull "$name" "$tmp" "$host_tar"
  incus_instance_exec "$name" rm -f "$tmp" || true
}

incus_dir_push_tar() {
  local name="$1"
  local host_dir="$2"
  local guest_parent="$3"
  local tmp_host
  tmp_host="$(mktemp --suffix=.tar)"
  tar -C "$(dirname "$host_dir")" -cf "$tmp_host" "$(basename "$host_dir")"
  incus_file_push "$name" "$tmp_host" "/tmp/incus-rest-push.tar" "0600" 0 0
  incus_instance_exec "$name" mkdir -p "$guest_parent"
  incus_instance_exec "$name" tar -C "$guest_parent" -xf /tmp/incus-rest-push.tar
  incus_instance_exec "$name" rm -f /tmp/incus-rest-push.tar || true
  rm -f "$tmp_host"
}
