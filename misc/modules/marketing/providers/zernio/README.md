# Zernio: on-demand workspace MCP

Use the installed `zernio-mcp` command. No editor MCP registration or background server. Transportation and tool discovery use the hosted MCP; there is no REST endpoint catalogue to maintain.

```sh
zernio-mcp routes instagram            # local config only; omit platform for all routes
zernio-mcp call coverlttr-free search_tools '{"query":"Instagram Business Discovery"}'
zernio-mcp tools coverlttr-free        # optional: top-level live MCP tool schemas
```

`routes` shows **configured** platforms, not live connection status or account IDs. Use the requested identity to disambiguate; if unsure, ask. Call known top-level tools directly with `zernio-mcp call WORKSPACE TOOL 'JSON'`. For a nested operation found via `search_tools`, use upstream `call_tool` with its advertised schema. If an operation requires an account ID, look it up in that workspace. Check target, delivery mode and approval before writes; don't retry creates blindly. Zernio permissions, login requirements and plan limits still apply.

## Setup

Keep the existing `zernio-secrets.json.age`. For a new workspace edit it with `manage-secret zernio-secrets.json.age` ([example](workspaces.example.json)) and activate the updated secret. No registry edit. Workspace platform lists guide routing, not permissions; authority is everything the selected key permits. The CLI passes only that workspace's credential to mcporter at runtime. Never print the key or put it in command arguments.
