#!/usr/bin/env bash
# Launch the OpenHands Agent Canvas *frontend* (browser client) for byok-agent.
#
# Agent Canvas is the successor to the legacy OpenHands Local GUI. It is only a
# client: this script deliberately runs `--frontend-only`, leaving the existing
# openhands-agent-server on :8000 as the single execution backend that Hermes
# and oh-start.sh already talk to. The frontend listens on CANVAS_PORT and is
# reverse-proxied by the host Caddy (agent.enesbala.com).
#
# Env:
#   CANVAS_PORT   listen port for the frontend ingress (default: 3000)
#   HOME          Agent Canvas stores its backend list under $HOME/.openhands

set -euo pipefail

for envfile in /etc/agent-env /etc/hermes-env; do
  if [[ -f "$envfile" ]]; then
    set -o allexport
    # shellcheck disable=SC1090
    source "$envfile"
    set +o allexport
  fi
done

export HOME="${HOME:-/root}"
export PATH="/usr/local/bin:/root/.local/bin:/usr/bin:$PATH"

CANVAS_PORT="${CANVAS_PORT:-3000}"

exec agent-canvas --frontend-only --port "$CANVAS_PORT"
