#!/usr/bin/env bash
# Start (or reuse) the dedicated Helium instance used by Playwright MCP.
#
# Separate profile + CDP port mean agent pages are tabs in ONE known window and
# the human's Helium on 9222 is never touched. No title marker, no window hooks,
# no teleporting: the window is parked on a fixed workspace once, at launch.
set -euo pipefail

PORT="${PLAYWRIGHT_AGENT_CDP_PORT:-9333}"
HOST="127.0.0.1"
PROFILE="${PLAYWRIGHT_AGENT_PROFILE:-${XDG_CACHE_HOME:-$HOME/.cache}/playwright-agent-helium}"
WORKSPACE="${PLAYWRIGHT_AGENT_WORKSPACE:-11}"
TIMEOUT=15

cdp_url="http://${HOST}:${PORT}"

for _ in 1 2 3; do
  if curl -sf --max-time 2 "${cdp_url}/json/version" >/dev/null 2>&1; then
    echo "${cdp_url}"
    exit 0
  fi
  sleep 0.5
done

helium_bin="${HELIUM_BIN:-$(command -v helium || true)}"
if [[ -z "$helium_bin" ]]; then
  echo "Error: Helium binary not found." >&2
  exit 1
fi

mkdir -p "$PROFILE"
args=(
  --remote-debugging-port="$PORT"
  --remote-debugging-address="$HOST"
  --remote-allow-origins=*
  --user-data-dir="$PROFILE"
  --no-first-run
  --no-default-browser-check
  about:blank
)

echo "Launching dedicated agent Helium on ${cdp_url}" >&2
if command -v hypruse >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-${DISPLAY:-}}" ]]; then
  # Desktop host: park the single window on the automation workspace.
  echo "Placing window on workspace ${WORKSPACE}" >&2
  hypruse launch --workspace "$WORKSPACE" --wait "$TIMEOUT" -- "$helium_bin" "${args[@]}" >&2
else
  # Headless host (e.g. home server): no Hyprland, no window to place.
  "$helium_bin" --headless --no-sandbox "${args[@]}" >/dev/null 2>&1 &
fi

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
  if curl -sf "${cdp_url}/json/version" >/dev/null 2>&1; then
    echo "${cdp_url}"
    exit 0
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done

echo "Error: agent Helium did not open CDP on ${cdp_url} within ${TIMEOUT}s" >&2
exit 1
