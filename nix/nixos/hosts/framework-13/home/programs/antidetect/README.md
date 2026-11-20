# Antidetect browsers (framework-13)

Thin Home Manager modules that install **Donut Browser** and **AliasMode**.

- Nix owns: install, desktop entries, and the Agenix secret path.
- The browsers own: profiles, cookies, extensions, and proxy attachment.

## Secrets

`"proxies-us.age"` is declared in `nix/secrets/secrets.nix`.

Create and populate it:

```bash
manage-secret proxies-us.age
# or: agenix -e nix/secrets/proxies-us.age
```

Suggested format (one proxy per line, or simple JSON):

```
host:port:user:pass
# or
{"host":"...","port":...,"user":"...","pass":"..."}
```

The decrypted file is available at runtime via `$PROXIES_US` (points to `/run/agenix/proxies-us`).

## PENDING

- Bulk proxy import scripts for both browsers.
  - Donut: local API available on the free tier.
  - AliasMode: Local API + MCP.
- Small helpers that read `/run/agenix/proxies-us` and feed each browser’s import format.

No Playwright proxy integration or cross-OS fingerprint work in this PR.
