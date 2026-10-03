#!/usr/bin/env bash
# Point a guest agent at the host Helium Playwright MCP.
# Runs inside the guest (cloud-init or `incus exec`).
set -euo pipefail

ROLE="${1:?usage: configure-browser-mcp.sh hermes|openhands}"
URL="${HELIUM_MCP_URL:-http://10.0.100.1:8931/mcp}"
RECORDINGS="${HELIUM_RECORDINGS:-/var/lib/helium-browser/recordings}"

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
    HELIUM_MCP_URL="$URL" python3 - <<'PY'
import os
from pathlib import Path
import yaml

url = os.environ["HELIUM_MCP_URL"]
path = Path("/root/.hermes/config.yaml")
path.parent.mkdir(parents=True, exist_ok=True)
data = {}
if path.exists() and path.read_text().strip():
    loaded = yaml.safe_load(path.read_text())
    if not isinstance(loaded, dict):
        raise SystemExit("refusing to edit /root/.hermes/config.yaml: not a mapping")
    data = loaded
servers = data.get("mcp_servers") or {}
if not isinstance(servers, dict):
    raise SystemExit("refusing to edit mcp_servers: not a mapping")
current = servers.get("helium-browser")
if current != {"url": url}:
    backup = path.with_name("config.yaml.bak-helium")
    if path.exists() and not backup.exists():
        backup.write_text(path.read_text())
    servers["helium-browser"] = {"url": url}
    data["mcp_servers"] = servers
    path.write_text(yaml.safe_dump(data, sort_keys=False))
path.chmod(0o600)
PY
    ;;
  openhands)
    HELIUM_MCP_URL="$URL" python3 - <<'PY'
import json
import os
from pathlib import Path

url = os.environ["HELIUM_MCP_URL"]
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
entry = {"url": url}
if servers.get("helium-browser") != entry:
    backup = path.with_name("mcp.json.bak-helium")
    if path.exists() and not backup.exists():
        backup.write_text(path.read_text())
    servers["helium-browser"] = entry
    data["mcpServers"] = servers
    path.write_text(json.dumps(data, indent=2) + "\n")
path.chmod(0o600)
PY
    ;;
  *)
    echo "Unknown role: $ROLE" >&2
    exit 1
    ;;
esac

echo "helium-browser MCP -> ${URL} (${ROLE})"
