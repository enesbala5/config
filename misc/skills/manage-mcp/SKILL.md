---
name: manage-mcp
description: Add, remove, list, or update MCP servers in the user's persistent config and sync pi, Cursor, and Zed. Use for /manage-mcp add <url>, /manage-mcp remove <name>, or requests to persist an MCP server across clients.
---

# Manage MCP

Manage the shared MCP configuration, not just the current client's generated file.

## Commands

- `/manage-mcp add https://mcp.synthesia.io/mcp`
- `/manage-mcp add synthesia https://mcp.synthesia.io/mcp`
- `/manage-mcp remove synthesia`
- `/manage-mcp list`

Pi's native invocation is `/skill:manage-mcp <arguments>`; other clients may expose `/manage-mcp` directly. Treat either spelling in a user request as this workflow.

## Source of truth

Resolve the config checkout from `MCP_CONFIG_DIR`, defaulting to `~/config`. Read these files before editing:

- `misc/mcp/mcp.json`: tracked canonical server definitions.
- `scripts/utilities/mcp-sync.mjs`: client sync implementation.

The sync script writes `~/.pi/agent/mcp.json`, `~/.cursor/mcp.json`, and Zed's `context_servers`. Zed's settings may be symlinked to tracked `tools/zed/settings.json`. OpenCode reads the canonical JSON during Nix evaluation, so it needs the user's normal rebuild to pick up changes.

`nix/secrets/mcp-secrets.json.age` is encrypted credential storage, declared in `nix/secrets/secrets.nix`. Runtime values come from `/run/agenix/mcp-secrets.json` (or `MCP_SECRETS`). It is not the server registry. Never print decrypted secrets or generated configs containing resolved headers. Do not change secrets for a URL-only addition.

## Workflow

1. Inspect `git status --short` and read the canonical config and sync script. Preserve unrelated edits.
2. Apply the requested operation:
   - **Add:** require an HTTP(S) URL. Use the explicit name if supplied; otherwise infer a concise service name from the hostname (`mcp.synthesia.io` → `synthesia`). Names must match `[A-Za-z0-9_-]+`. Add an object with `url` and a short factual `description`, preserving existing entries and formatting. Default to enabled; do not invent headers, credentials, OAuth settings, or capability claims. If the same URL already exists, report its existing name rather than adding a duplicate. If a name already belongs to a different URL, ask before replacing it.
   - **Remove:** remove only the exact named entry. If it does not exist, report that without changing anything. Do not delete shared secrets or OAuth state. An explicit removal request authorizes removing that server; no extra confirmation is needed.
   - **Update:** modify only requested fields. Ask before replacing a server when intent is ambiguous.
   - **List:** show names, URLs or commands, and enabled status from the canonical file only. Never display header values or secret-bearing environment values. Do not run sync for a read-only listing.
3. From the config checkout, run `node scripts/utilities/mcp-sync.mjs`, then `node scripts/utilities/mcp-sync.mjs --check`. The second command must report `already up to date`; its exit code alone is not a drift check. If sync fails because a secret is unavailable, report the error without exposing values; leave the canonical edit in place and state which sync remains incomplete. Do not invent credentials or bypass the normal secret flow.
4. Review diffs for the canonical JSON and tracked Zed settings. Validate that only the requested server changed. Report persistence and client-sync status separately from connection/authentication status. Do not commit unless explicitly requested.

## Authentication and verification

A saved configuration is not proof that tools connect. An optional HTTP probe can establish reachability, but GET may legitimately return 405 for an MCP endpoint. Do not call that an authentication or protocol success. If sign-in is required, direct the user to their client's authentication flow; never claim login succeeded without verification.

For credentials the user explicitly asks to persist, inspect the repository's existing agenix workflow first. Keep `${TOKEN_NAME}` placeholders in the canonical file, use the established encrypted-secret workflow, and never put plaintext tokens in tracked files or command output.

## Final response

State the server added/removed, the persistent file path, and sync result. Mention a rebuild only for OpenCode. If the client must reconnect or authenticate, give one concrete next action. For this newly created or edited skill, Pi discovers changes with `/reload`; do not assume the live session has already loaded it.
