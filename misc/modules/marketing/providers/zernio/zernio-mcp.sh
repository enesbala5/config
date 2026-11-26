#!/usr/bin/env bash
# Workspace selection only; mcporter speaks MCP and Zernio owns the tool schemas.
set -euo pipefail
usage() { echo 'Usage: zernio-mcp routes [PLATFORM] | tools WORKSPACE | call WORKSPACE TOOL [JSON_OBJECT]' >&2; exit 2; }
secret=/run/agenix/zernio-secrets.json
case ${1-} in
  routes)
    (( $# <= 2 )) || usage
    exec jq -e --arg p "${2-}" 'def norm: if . == "twitter" then "x" else . end; .workspaces | map_values(.accounts) | with_entries(select($p == "" or (.value | map(norm) | index($p | norm)) != null))' "$secret" ;;
  tools) (( $# == 2 )) || usage ;;
  call) (( $# == 3 || $# == 4 )) && [[ $3 =~ ^[a-zA-Z0-9_-]+$ ]] || usage ;;
  *) usage ;;
esac
if ! token=$(jq -er --arg w "$2" '.workspaces[$w].key | select(type == "string" and length > 0)' "$secret" 2>/dev/null); then
  echo 'Zernio workspace key missing or unreadable' >&2; exit 1
fi
cd -- "$(dirname -- "$(realpath -- "$0")")" # Never load MCP config from the caller's project.
export ZERNIO_MCP_AUTH="Bearer $token"
client=(mcporter --config "$PWD/mcporter.json")
if [[ $1 == tools ]]; then exec "${client[@]}" list zernio --schema; fi
args=${4-'{}'}
jq -e 'type == "object"' >/dev/null <<<"$args" || usage
exec "${client[@]}" call "zernio.$3" --args "$args" --output json
