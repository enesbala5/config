#!/usr/bin/env bash
# Local MCP command for a remote HTTP server.
# Any client that can launch a command can use this. Header templates may
# contain ${VAR}, filled from MCP_SECRETS (default /run/agenix/mcp-secrets.json)
# when this process starts.
#
# Usage: mcp-http.sh <url> [Name: template ...]
set -euo pipefail

if [[ $# -lt 1 || -z ${1:-} ]]; then
  echo "usage: mcp-http.sh <url> [Name: template ...]" >&2
  exit 1
fi

url=$1
shift
secrets=${MCP_SECRETS:-/run/agenix/mcp-secrets.json}

if [[ ! -f $secrets ]]; then
  echo "missing secrets: $secrets" >&2
  exit 1
fi

expand_template() {
  MCP_SECRETS_FILE=$secrets node --input-type=module -e '
    import fs from "node:fs";
    const file = process.env.MCP_SECRETS_FILE;
    const secrets = JSON.parse(fs.readFileSync(file, "utf8"));
    const template = process.argv[1];
    let unresolved = "";
    const out = template.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, name) => {
      const value = secrets[name];
      if (typeof value !== "string" || value === "") {
        unresolved = name;
        return "";
      }
      return value;
    });
    if (unresolved) {
      console.error(`unresolved \${${unresolved}} (add it to ${file})`);
      process.exit(1);
    }
    process.stdout.write(out);
  ' "$1"
}

if command -v mcp-remote >/dev/null 2>&1; then
  cmd=(mcp-remote "$url")
elif command -v npx >/dev/null 2>&1; then
  cmd=(npx -y mcp-remote@0.15.2 "$url")
else
  echo "mcp-remote not found (need mcp-remote or npx on PATH)" >&2
  exit 1
fi

for raw in "$@"; do
  if [[ ! $raw =~ ^[A-Za-z0-9_-]+: ]]; then
    echo "header must look like Name: template" >&2
    exit 1
  fi
  cmd+=(--header "$(expand_template "$raw")")
done

exec "${cmd[@]}"
