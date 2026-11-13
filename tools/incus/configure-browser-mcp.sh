#!/usr/bin/env bash
# Point a guest agent at the host Helium Playwright MCP.
# Runs inside the guest (cloud-init or `incus exec`).
#
# hermes: registers the MCP server as `playwright`, pins `browser.backend: "off"`
#   and adds `browser` to `agent.disabled_toolsets`. The disabled toolset is what
#   removes Hermes' own browser stack in the guest — `backend: "off"` only swaps
#   the Browser Use CLI driver for the built-in browser_* tools, which still need
#   a local Chromium. The installer never overwrites an existing config.yaml, and
#   this script re-runs on every first boot and every `hermes-vm-manage.sh start`,
#   so the setting survives a VM rebuild.
# openhands: registers the MCP server only (/root/.openhands/mcp.json).
set -euo pipefail

ROLE="${1:?usage: configure-browser-mcp.sh hermes|openhands}"
URL="${HELIUM_MCP_URL:-http://10.0.100.1:8931/mcp}"
RECORDINGS="${HELIUM_RECORDINGS:-/var/lib/helium-browser/recordings}"
# The endpoint is `@playwright/mcp` driving headless Helium (home-server
# helium-browser-mcp module); `helium-browser` was the previous entry name.
MCP_SERVER_NAME="playwright"
LEGACY_MCP_SERVER_NAME="helium-browser"

install -d -m 0755 "$RECORDINGS" /usr/local/share/helium-browser
printf 'HELIUM_MCP_URL=%s\nHELIUM_RECORDINGS=%s\n' "$URL" "$RECORDINGS" \
  > /etc/helium-browser.env
chmod 0644 /etc/helium-browser.env

ensure_pyyaml() {
  if python3 -c 'import yaml' >/dev/null 2>&1; then
    return 0
  fi
  apt-get update -qq
  apt-get install -y -qq python3-yaml
}

case "$ROLE" in
  hermes)
    ensure_pyyaml
    HELIUM_MCP_URL="$URL" MCP_SERVER_NAME="$MCP_SERVER_NAME" \
      LEGACY_MCP_SERVER_NAME="$LEGACY_MCP_SERVER_NAME" python3 - <<'PY'
import os
from pathlib import Path
import yaml

url = os.environ["HELIUM_MCP_URL"]
name = os.environ["MCP_SERVER_NAME"]
legacy_name = os.environ["LEGACY_MCP_SERVER_NAME"]
path = Path("/root/.hermes/config.yaml")
path.parent.mkdir(parents=True, exist_ok=True)
data = {}
if path.exists() and path.read_text().strip():
    loaded = yaml.safe_load(path.read_text())
    if not isinstance(loaded, dict):
        raise SystemExit("refusing to edit /root/.hermes/config.yaml: not a mapping")
    data = loaded

servers = data.get("mcp_servers")
if servers is None:
    servers = {}
if not isinstance(servers, dict):
    raise SystemExit("refusing to edit mcp_servers: not a mapping")
browser = data.get("browser")
if browser is None:
    browser = {}
if not isinstance(browser, dict):
    raise SystemExit("refusing to edit browser: not a mapping")
agent = data.get("agent")
if agent is None:
    agent = {}
if not isinstance(agent, dict):
    raise SystemExit("refusing to edit agent: not a mapping")

wanted_servers = dict(servers)
wanted_servers[name] = {"url": url}
# Drop the old name so an upgraded guest does not expose the same endpoint twice.
wanted_servers.pop(legacy_name, None)

# "off" disables the Browser Use CLI driver — and silences the notice Hermes
# prints when that CLI is absent, which it now is (the installer runs with
# --skip-browser). It does NOT remove the built-in browser_* tools.
wanted_browser = dict(browser)
wanted_browser["backend"] = "off"

# `agent.disabled_toolsets` is the global suppression list, applied after the
# platform toolsets, so the built-in browser toolset is never registered and the
# MCP tools above are the only browser surface in the guest.
current_disabled = agent.get("disabled_toolsets")
if current_disabled is None:
    current_disabled = []
elif isinstance(current_disabled, str):
    # Hermes accepts the scalar form; normalise it to a list on write.
    current_disabled = [current_disabled]
elif not isinstance(current_disabled, list):
    raise SystemExit("refusing to edit agent.disabled_toolsets: not a list")
wanted_disabled = list(current_disabled)
if "browser" not in wanted_disabled:
    wanted_disabled.append("browser")
wanted_agent = dict(agent)
wanted_agent["disabled_toolsets"] = wanted_disabled

# Every edit is desired state: rewrite (and back up) only on a real change.
if (
    wanted_servers != servers
    or wanted_browser != browser
    or wanted_agent != agent
):
    backup = path.with_name("config.yaml.bak-helium")
    if path.exists() and not backup.exists():
        backup.write_text(path.read_text())
    data["mcp_servers"] = wanted_servers
    data["browser"] = wanted_browser
    data["agent"] = wanted_agent
    path.write_text(yaml.safe_dump(data, sort_keys=False))
path.chmod(0o600)
PY
    ;;
  openhands)
    HELIUM_MCP_URL="$URL" MCP_SERVER_NAME="$MCP_SERVER_NAME" \
      LEGACY_MCP_SERVER_NAME="$LEGACY_MCP_SERVER_NAME" python3 - <<'PY'
import json
import os
from pathlib import Path

url = os.environ["HELIUM_MCP_URL"]
name = os.environ["MCP_SERVER_NAME"]
legacy_name = os.environ["LEGACY_MCP_SERVER_NAME"]
path = Path("/root/.openhands/mcp.json")
path.parent.mkdir(parents=True, exist_ok=True)
data = {"mcpServers": {}}
if path.exists() and path.read_text().strip():
    loaded = json.loads(path.read_text())
    if not isinstance(loaded, dict):
        raise SystemExit("refusing to edit /root/.openhands/mcp.json: not an object")
    data = loaded
servers = data.get("mcpServers")
if servers is None:
    servers = {}
if not isinstance(servers, dict):
    raise SystemExit("refusing to edit mcpServers: not an object")
wanted_servers = dict(servers)
wanted_servers[name] = {"url": url}
wanted_servers.pop(legacy_name, None)
if wanted_servers != servers:
    backup = path.with_name("mcp.json.bak-helium")
    if path.exists() and not backup.exists():
        backup.write_text(path.read_text())
    data["mcpServers"] = wanted_servers
    path.write_text(json.dumps(data, indent=2) + "\n")
path.chmod(0o600)
PY
    ;;
  *)
    echo "Unknown role: $ROLE" >&2
    exit 1
    ;;
esac

echo "${MCP_SERVER_NAME} MCP (host Helium) -> ${URL} (${ROLE})"
