#!/usr/bin/env bash
# Playwright MCP entrypoint. Uses the dedicated agent Helium instance so pages
# open as tabs in one known window instead of creating windows that get moved.
set -euo pipefail
ENDPOINT="${PLAYWRIGHT_MCP_CDP_ENDPOINT:-http://127.0.0.1:9333}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Bring up the agent browser and park its window on the automation workspace.
"$SCRIPT_DIR/playwright-helium.sh" >&2

exec npx -y @playwright/mcp@latest --cdp-endpoint="$ENDPOINT" "$@"
