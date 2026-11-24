# Plan: Confirm the private port and tunnel path.

- Status: draft
- Created: 2026-11-24T15:13:43.078Z
- Project: `/home/e/config`

## Steps

- [ ] 1. Confirm the private port and tunnel path.
- [ ] 2. One /refero route to the existing Caddy module.
- [ ] 3. Publish and verify before switching clients.

## Plan

**Use the existing Caddy as the proxy, Nix to configure it, and Cloudflare Tunnel to publish it.** That gives you a local service on a dedicated port without writing a TypeScript app or running another process.

```text
MCP client
  │  HTTPS + gateway token
  ▼
mcp.enesbala.com/refero
  │  Cloudflare Tunnel
  ▼
Caddy on home-server — private listener, e.g. port 8787
  ├─ /refero → check gateway token, send Refero token → api.refero.design/mcp
  ├─ /future → its own token and fixed upstream     → another MCP
  └─ anything else → 404
```

**Why this stack:** Nix declares the listener and routes; Caddy handles HTTP proxying and streaming; agenix supplies secrets at runtime. To add an MCP, add another Caddy route and apply the Nix config. No periodic rebuilds. I’d reach for **Go with `httputil.ReverseProxy`** only if we later need custom behavior like OAuth token refresh or routes that change without a deploy. For fixed upstreams with bearer tokens, there’s no app code to maintain.

## Plan:

1. **Confirm the private port and tunnel path.** Check what currently owns `mcp.enesbala.com` and which host address the existing `cloudflared` connector can reach. Bind only the new listener there; don’t expose the port to the internet or change the Tailscale dashboard listeners. **Files:** none.
2. **Add one `/refero` route to the existing Caddy module.** Match the exact path, reject invalid or missing gateway tokens, and replace `Authorization` with the server-side Refero token before forwarding to the fixed `/mcp` endpoint. Preserve MCP session headers and streaming. Keep both tokens out of the Nix store and logs, and test that missing secrets fail closed. Start with a plain Caddy route block rather than a generic Nix helper. **Files:** `nix/nixos/hosts/home-server/modules/caddy/default.nix` and new server-scoped agenix secret and recipient files.
3. **Publish and verify before switching clients.** Point the Cloudflare hostname at the private listener. From outside Tailscale, test an unknown path, a bad token, and a valid `initialize` → `tools/list` exchange. Then configure your clients with **only** the gateway token. **Files:** `misc/mcp/mcp.json`, `nix/secrets/mcp-secrets.json.age`, and generated client settings; one Cloudflare hostname mapping.

No changes made. **I’d start with one Caddy listener and one route.**
