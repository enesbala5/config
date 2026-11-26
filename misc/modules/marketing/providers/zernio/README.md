# Zernio: social delivery

Lists connected accounts, resolves platform names, creates posts and checks status through `https://zernio.com/api/v1`. Workspace plans and limits vary. Marketing hands off; the `social` skill owns delivery.

## One-time setup (Nix host)

1. Run `manage-secret zernio-secrets.json.age`. Paste [workspaces.example.json](workspaces.example.json) into the editor and fill the empty `key` strings **there**, never in the tracked template. These are the three workspace groups from the original posting workflow. Remove platforms or groups you don't use. No env vars, account IDs, JSON Schema or MCP changes needed.
2. Ensure the new **encrypted** `nix/secrets/zernio-secrets.json.age` is included in the flake source (`git add nix/secrets/zernio-secrets.json.age` for a Git flake). Activate your usual NixOS configuration with the CLI changes included. Only the runtime file `/run/agenix/zernio-secrets.json` contains plaintext. The CLI reads it on the runner, not from your current repo.
3. Run `marketing-zernio accounts personal`. This read-only check lists allowed connected accounts; `x` is displayed as `twitter`. For rotation or reconnects, update the secret and reactivate if keys/platforms changed. IDs are discovered on every request. Existing MCP credentials and remote runners are not migrated.

## Usage

```sh
marketing-zernio accounts coverlttr-paid
marketing-zernio draft coverlttr-paid --request-id <stable-id> < post.json
marketing-zernio status coverlttr-paid <returned-post-id>
```

Replace angle-bracket placeholders before running. A minimal `post.json`:

```json
{"content":"Approved copy", "platforms":[{"platform":"x"}]}
```

Use `schedule` instead of `draft` with `scheduledFor` and `timezone` in the payload, or `publish` for explicitly approved immediate delivery. Do not set `isDraft` or `publishNow` yourself. Normal Zernio fields such as `mediaItems`, `customContent` and `platformSpecificData` pass through. Use one stable request ID per logical create per workspace; reuse it only for that exact retry. Check status after creating, or the dashboard if the response was lost. Never blindly retry a create.

If a platform matches multiple connected accounts, use `accounts` to identify the intended account and set `accountId` on that platform **in the post only**. If none match, verify the allowlist and connection before retrying. Missing secrets, empty keys, HTTP failures and ambiguous routes fail without exporting credentials. Access to the decrypted file is access to all configured workspaces.
