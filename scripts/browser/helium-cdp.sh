#!/usr/bin/env bash
# Start Helium (or Chrome) with a localhost CDP port, or reuse one already up.
# Default profile — do not pass --user-data-dir unless --isolated is set.
set -euo pipefail

PORT="${PLAYWRIGHT_CDP_PORT:-9222}"
HOST="127.0.0.1"
TIMEOUT=15
BROWSER_KIND="helium"
ISOLATED=false
PROFILE=""

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  echo "Usage: helium-cdp [--chrome] [--isolated] [--port N] [--timeout S]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chrome) BROWSER_KIND="chrome"; shift ;;
    --isolated) ISOLATED=true; shift ;;
    --port) PORT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; usage >&2; exit 1 ;;
  esac
done

cdp_url="http://${HOST}:${PORT}"

if version_info=$(curl -sf "${cdp_url}/json/version"); then
  echo "${cdp_url}"
  echo "${version_info}" >&2
  exit 0
fi

helium_bin="${HELIUM_BIN:-$(command -v helium || true)}"
chrome_bin="$(command -v google-chrome-stable || command -v google-chrome || true)"

if [[ "$BROWSER_KIND" == "helium" ]]; then
  browser_bin="$helium_bin"
  name="Helium"
else
  browser_bin="$chrome_bin"
  name="Chrome"
fi

if [[ -z "$browser_bin" ]]; then
  echo "Error: ${name} binary not found." >&2
  exit 1
fi

if pgrep -u "$USER" -f "$browser_bin" >/dev/null 2>&1; then
  echo "Error: ${name} is running without CDP on ${cdp_url}." >&2
  echo "Quit ${name} completely, then run: helium-cdp" >&2
  exit 1
fi

if [[ "$ISOLATED" == true ]]; then
  PROFILE="${XDG_CACHE_HOME:-$HOME/.cache}/playwright-cdp-profile-${BROWSER_KIND}-${PORT}"
  mkdir -p "$PROFILE"
fi

args=(
  --remote-debugging-port="$PORT"
  --remote-debugging-address="$HOST"
  --remote-allow-origins=*
)
if [[ -n "$PROFILE" ]]; then
  args+=(--user-data-dir="$PROFILE" --no-first-run --no-default-browser-check)
fi

echo "Launching ${name} with CDP ${cdp_url}" >&2
"$browser_bin" "${args[@]}" >/dev/null 2>&1 &

elapsed=0
while [[ $elapsed -lt $TIMEOUT ]]; do
  if version_info=$(curl -sf "${cdp_url}/json/version"); then
    echo "${cdp_url}"
    echo "${version_info}" >&2
    exit 0
  fi
  sleep 1
  elapsed=$((elapsed + 1))
done

echo "Error: ${name} did not open CDP on ${cdp_url} within ${TIMEOUT}s" >&2
exit 1
