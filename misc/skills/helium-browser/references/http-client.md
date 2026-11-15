# Browser tools without an agent MCP integration

The configured browser service exposes standard MCP Streamable HTTP at
`http://10.0.100.1:8931/mcp`, reachable from its Incus guest. No bearer token is
configured for this private-network endpoint; do not expose it publicly. The
service and shared browser must already be running on the host (the guest
configuration does not start a local browser). Prerequisites: `curl`, `jq`, and
ordinary POSIX shell utilities. Override `BROWSER_MCP_URL` only with an operator-
provided endpoint. Do not guess credentials or open firewall ports on failure.

In a shell, initialize a session, discover tools, and call them:

```bash
URL="${BROWSER_MCP_URL:-http://10.0.100.1:8931/mcp}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl --fail-with-body --silent --show-error --max-time 20 \
  -D "$TMP/headers" -o "$TMP/initialize" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"browser-shell","version":"1"}}}' \
  "$URL"
SESSION=$(awk 'tolower($1)=="mcp-session-id:" {gsub("\r", "", $2); print $2}' "$TMP/headers")

mcp() {
  if [ -n "$SESSION" ]; then
    curl --fail-with-body --silent --show-error --max-time 20 \
      -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
      -H 'MCP-Protocol-Version: 2025-03-26' -H "Mcp-Session-Id: $SESSION" \
      --data "$1" "$URL"
  else
    curl --fail-with-body --silent --show-error --max-time 20 \
      -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
      -H 'MCP-Protocol-Version: 2025-03-26' --data "$1" "$URL"
  fi
}
mcp '{"jsonrpc":"2.0","method":"notifications/initialized"}'
mcp '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
# Read each tool's name/inputSchema before choosing arguments. Example:
mcp '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"browser_snapshot","arguments":{}}}'
```

Responses may be JSON or SSE (`data: {…}` lines). Check JSON-RPC `error` and tool
`isError`, not just HTTP status. For screenshots use the screenshot tool's
advertised schema; image content is base64 in the result, and any file paths
belong to the browser service host, not necessarily the guest. Read back the
snapshot or screenshot to verify an action. Existing video/trace artifacts use
the shared recordings directory documented in SKILL.md; do not assume a new
recording exists without checking the artifact.

Connection failures: confirm the host browser/MCP service is running and the
private endpoint is reachable. HTTP 404 for a stale session: initialize again.
A protocol-version error requires using a version the server advertises. A
transport timeout or permission error is not permission to create a separate
browser session or bypass the service's controls. Do not retry non-idempotent
browser actions blindly after a transport failure; inspect browser state first.
