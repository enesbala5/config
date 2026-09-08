#!/usr/bin/env bash
# Cursor MCP entrypoint. Prefers the Home Manager wrapper after rebuild.
set -euo pipefail
ENDPOINT="${PLAYWRIGHT_MCP_CDP_ENDPOINT:-http://127.0.0.1:9222}"

if command -v playwright-mcp >/dev/null 2>&1 && [[ "$(command -v playwright-mcp)" != "$0" ]]; then
  exec playwright-mcp "$@"
fi

run_mcp() {
  exec npx -y @playwright/mcp@latest --cdp-endpoint="$ENDPOINT" "$@"
}

if command -v npx >/dev/null 2>&1; then
  run_mcp
fi

exec nix-shell -p nodejs --run "npx -y @playwright/mcp@latest --cdp-endpoint=${ENDPOINT} $*"
