#!/bin/sh
# Entrypoint for every hook in herdr-plugin.toml. Herdr spawns argv directly (no
# shell), so this launcher finds a real Node.js binary and enforces a singleton:
# Herdr may fire the startup hook more than once (server reload, reattach), and
# two daemons would fight over the same $head token.
set -eu

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
state="${XDG_RUNTIME_DIR:-/tmp}/herdr-agent-head.pid"

stop_existing() {
  # Kill by script path, not just the pidfile: the startup hook can fire
  # concurrently with a manual action, so the pidfile only remembers the most
  # recent start and a pidfile-only stop leaks the other daemon.
  dir_esc=$1
  pkill -TERM -f "$dir_esc/head.js" 2>/dev/null || true
  old=$(cat "$state" 2>/dev/null || true)
  if [ -n "${old:-}" ] && kill -0 "$old" 2>/dev/null; then
    kill -TERM "$old" 2>/dev/null || true
  fi
  rm -f "$state"
  # Let the SIGTERM handler clear its tokens before we start a replacement.
  sleep 1
}

# Stopping must work even where node has gone missing.
[ "${1:-}" = --stop ] && { stop_existing "$dir"; exit 0; }

node_bin="${HERDR_AGENT_HEAD_NODE:-}"
if [ -z "$node_bin" ] && command -v node >/dev/null 2>&1; then
  node_bin=node
fi
if [ -z "$node_bin" ]; then
  for cand in "$HOME"/.nvm/versions/node/*/bin/node /usr/local/bin/node /opt/homebrew/bin/node; do
    [ -x "$cand" ] && node_bin="$cand"
  done
fi
if [ -z "$node_bin" ]; then
  echo "agent-head: no node binary found; set HERDR_AGENT_HEAD_NODE" >&2
  exit 1
fi

case "${1:-}" in
  --restart) stop_existing "$dir" ;;
  *) stop_existing "$dir" ;;
esac

# Detach so the hook returns immediately; Herdr should not wait on a daemon.
"$node_bin" "$dir/head.js" >/dev/null 2>&1 &
echo $! > "$state"
