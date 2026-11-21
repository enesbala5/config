# OpenSEO: restore service with password auth (Plan A)

Date: 2026-11-21
Tracker: https://github.com/enesbala5/openseo/issues/1
Decision: migrate to upstream's standalone stack with `AUTH_MODE=password`.
Admin email for the imported legacy admin: `contact@enesbala.com` (password chosen by owner, never stored in this plan).
Outage is intentional; domain stays blocked until acceptance passes.

## Verified starting state

- Coolify app **OpenSEO** `x1bljvfwswxr1zehhdyunljz`, project **Tools** `q08oo8kw0csc8wog08o8kwso`, server **localhost** `rocwcwsc0g04sg04c4g4osk0`.
- Build pack `dockercompose`, repo `enesbala5/openseo` @ `main`, compose `/compose.yaml`.
- Status `exited:unhealthy`, container absent, last online 2026-11-19. `https://openseo.enesbala.com`, `/mcp`, `/api/health` all 502.
- Data volume: `x1bljvfwswxr1zehhdyunljz_open-seo-data` → `/app/.wrangler`.
- Env keys present (values unreadable: token lacks `read:sensitive`): `AUTH_MODE`, `BETTER_AUTH_SECRET`, `BETTER_AUTH_URL`, `ALLOWED_HOST`, `PORT`, `DATAFORSEO_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `OPENSEO_TELEMETRY_DISABLED`, `DO_NOT_TRACK`, `OPEN_SEO_IMAGE`, `SERVICE_FQDN_OPEN_SEO`, `SERVICE_URL_OPEN_SEO`.
- Stale domain binding: `{"open-seo":{"domain":"http://openseo.enesbala.com:3001"}}`; `ports_exposes: 3000`. Current compose publishes `127.0.0.1:3001:3001`.
- Local fork clone: `/home/e/dev/misc/openseo` @ `7e04e1cf` (clean). Its `compose.yaml:19` hardcodes `AUTH_MODE=local_noauth`; `src/lib/auth-mode.ts` only knows `cloudflare_access | local_noauth | hosted`. So a Coolify env change cannot enable password auth on this image.
- Password mode exists only in upstream standalone (`open-seo-standalone`), added in v0.1.17.
- Prior work: branches `docs/issue-1-password-coolify` (runbook) and `fix/issue-1-password-auth` (fork upgrade) both pushed to origin, not deployed.
- Local `docker` has unrelated volume `openseo_open_seo_data`; production volume is on the Coolify host.

## Why Plan A

Upstream documents exactly one supported path from the legacy image to email/password accounts: a new standalone stack plus one-time data import. It preserves projects, saved keywords, rank trackers/history, audits, reports and SAM conversations. It does not preserve Google connections, sessions, API keys, MCP grants, provider caches or in-flight work. The old service and volume are kept for rollback until acceptance passes.

Image refs verified during the earlier investigation (re-verify digests before use):
- `ghcr.io/every-app/open-seo-standalone:v0.1.27` — `sha256:e0687b1d3aa0671c401ca39c5bbf7b57a478433f17b7ee0169b1c4f72ee5865e`
- `ghcr.io/every-app/open-seo:v0.1.27` (export source only) — `sha256:ce005c175150993bade99e7e11c12ac861e5ab85cf42198f5c405eb4d27b7ec4`

## Prerequisites

1. Owner generates an 8–128 char admin password in a password manager; do not put it in chat, git, plan files or command arguments.
2. Owner generates a unique `STORAGE_SECRET_KEY` (>= 32 random chars, e.g. `openssl rand -hex 32`).
3. Downtime window; domain remains blocked at the proxy throughout.
4. Shell access on the Coolify host for export/import/claim (not available from this laptop; no SSH alias configured). Either supply an SSH target or run those steps on the host.
5. At least 4 GiB free memory on the host; no paid research calls during validation.
6. Do not set `BETTER_AUTH_SECRET` in the new service — upstream's `configure.mjs` generates it, plus operator/crawl-gateway secrets, in the persistent `config` volume.

Shell variables for host steps:

```sh
ADMIN_EMAIL='contact@enesbala.com'
PUBLIC_URL='https://openseo.enesbala.com'
OLD_VOLUME='x1bljvfwswxr1zehhdyunljz_open-seo-data'
STANDALONE_IMAGE='ghcr.io/every-app/open-seo-standalone:v0.1.27@sha256:e0687b1d3aa0671c401ca39c5bbf7b57a478433f17b7ee0169b1c4f72ee5865e'
LEGACY_IMAGE='ghcr.io/every-app/open-seo:v0.1.27@sha256:ce005c175150993bade99e7e11c12ac861e5ab85cf42198f5c405eb4d27b7ec4'
```

## Steps

### 1. Close and preserve

- In Coolify, confirm the old app has no domain and is stopped (`manage_application` update to clear domains; `control` action `stop` if needed). Do not delete it or its volume.
- Disable auto-deploy on the old app.
- On the host: archive the old volume read-only with `tar` via `LEGACY_IMAGE` into a mode-0700 backup dir, record `sha256sum`, and sync the archive off-host.
- Run the legacy image once privately (`OPEN_SEO_IMAGE=$LEGACY_IMAGE`, old compose) so DB migrations finish; wait for running work; stop again; take a second backup.

### 2. Export the legacy data

```sh
EXPORT_DIR="/srv/backups/openseo-export-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 700 "$EXPORT_DIR"
docker run --rm --network none -u 0 \
  -v "${OLD_VOLUME}:/legacy:ro" -v "${EXPORT_DIR}:/export" -w /app \
  --entrypoint node "$LEGACY_IMAGE" \
  scripts/celld/export-legacy.mjs /legacy/state/v3 /export
```

Read `manifest.json`; confirm expected project count and note documented omissions. Keep the export until acceptance passes.

### 3. Create the new Coolify service

Use `create_service` with `action: "compose"` (Docker Compose Empty) in project `q08oo8kw0csc8wog08o8kwso`, environment of the old app (`dscs0goc0kgookwo8cwk0c4c`), server `rocwcwsc0g04sg04c4g4osk0`. Paste upstream v0.1.27 `deploy/standalone/compose.yaml` (base64 in `docker_compose_raw`), name `OpenSEO Auth`, no domain, `instant_deploy: false`.

Set env with `manage_env` (`bulk_update`), no preview values:

```dotenv
OPENSEO_IMAGE=<pinned standalone image + digest>
AUTH_MODE=password
BETTER_AUTH_URL=https://openseo.enesbala.com
STORAGE_ACCESS_KEY=openseo
STORAGE_SECRET_KEY=<owner-generated random value>
PORT=3001
```

Copy by name from the old deployment without rotating: `DATAFORSEO_API_KEY`, `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL` (if present), `OPENROUTER_MODEL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`. Values are not readable via this MCP token; obtain them from Coolify UI (or grant `read:sensitive`). Do not invent or print them.

Deploy via `deploy` (new service UUID). Wait for `init` to log `OpenSEO initialized and ready.` (the `init` container exiting is expected). Inspect **Show Deployable Compose** to confirm `AUTH_MODE=password`, pinned image, and only loopback port publishing.

### 4. Import and claim before exposing

Find the new runtime container (new service UUID from step 3):

```sh
NEW_RUNTIME="$(docker ps -q \
  --filter "label=coolify.serviceUuid=${NEW_SERVICE_UUID}" \
  --filter 'label=com.docker.compose.service=runtime')"

docker exec "$NEW_RUNTIME" mkdir -p /tmp/openseo-import
docker cp "${EXPORT_DIR}/." "${NEW_RUNTIME}:/tmp/openseo-import/"
docker exec -u 0 "$NEW_RUNTIME" node /opt/standalone/import.mjs /tmp/openseo-import
docker restart "$NEW_RUNTIME"
```

Claim the imported admin with the password on stdin (no argv, no history):

```bash
read -rs -p 'Admin password: ' password; printf '\n'
printf '%s\n' "$password" | docker exec -i -u 0 "$NEW_RUNTIME" \
  node /opt/standalone/admin.mjs claim-legacy-user \
  local-admin "$ADMIN_EMAIL" delegated-local-admin
unset password
```

Require `claim-legacy-user succeeded`. This closes public registration. Remove `/tmp/openseo-import` afterwards.

### 5. Cut over

- In the new service, attach `https://openseo.enesbala.com` to the `web` component on container port **80** (not `open-seo:3001`), forwarding WebSocket upgrades for SAM.
- Keep the old service stopped and domain-free; only `web` in the new stack reachable from the proxy.

### 6. Verify (all read-only / free)

1. `curl -fsS https://openseo.enesbala.com/api/health` → `authMode: password`, no `local_noauth` warning.
2. Fresh browser session: project pages redirect to sign-in; unrelated visitor cannot register.
3. Sign in as `contact@enesbala.com`; confirm **Coverlttr** and **Portfolio** projects, reports and saved data exist.
4. Anonymous and fake-key MCP calls must return 401/403:

```sh
curl -sS -o /dev/null -w '%{http_code}\n' "$PUBLIC_URL/mcp" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"whoami","arguments":{}}}'
# repeat with -H 'Authorization: Bearer oseo_invalid'
```

5. Create a long-lived `oseo_` key in Settings; store privately in `OPENSEO_MCP_TOKEN_FILE` (mode 0600); verify `whoami`, `list_projects`, `get_project_context` authenticate as the claimed account. Do not run research / rank checks / audits / AI visibility.

Acceptance = issue #1 checklist fully green, then record results on the issue.

### 7. Rewire clients

- `/home/e/config/misc/mcp/mcp.json:33` and `/home/e/config/tools/zed/settings.json:67` keep `https://openseo.enesbala.com/mcp`; switch from no-auth to OAuth or the new `oseo_` key as each client supports.
- Reconnect Cursor per upstream MCP docs; old OAuth grants and API keys do not survive import.
- Coverlttr GEO CLI: `OPENSEO_MCP_URL=https://openseo.enesbala.com/mcp`, `OPENSEO_MCP_TOKEN_FILE=<private file>`.

## Rollback

Keep the domain blocked. Stop the new stack without `-v`; point the old service back to its original compose/image/env and volume; restore from the pre-upgrade backup if the legacy image was changed. Never expose that rollback publicly (it restores `local_noauth`). Writes made in the new stack are not copied back automatically. Do not `docker compose down -v`, delete the legacy volume, or replace the new `config` volume.

## Fork deletion (deferred — needs scope confirmation)

Owner asked to delete the fork "in the meantime". Not done during planning (Plan mode forbids modifications). Risks to resolve first:

- The fork is still the git source of the current Coolify app; deleting it removes the rollback path.
- Both branches `docs/issue-1-password-coolify` and `fix/issue-1-password-auth` live on the fork; the runbook and rollout doc are only there. Copy them locally first.
- Need to know whether "delete" means the local clone `/home/e/dev/misc/openseo`, the GitHub repo `enesbala5/openseo`, or both.

Recommendation: defer deletion until Plan A acceptance passes and the runbook is copied into `/home/e/config/misc/plans/`. Then delete with explicit confirmation of scope.

## Sources

- https://openseo.so/docs/self-hosting
- https://openseo.so/docs/self-hosting/docker
- https://raw.githubusercontent.com/every-app/open-seo/main/docs/SELF_HOSTING_DOCKER.md
- https://raw.githubusercontent.com/every-app/open-seo/main/docs/SELF_HOSTING_DOCKER_LEGACY.md
- https://raw.githubusercontent.com/every-app/open-seo/main/deploy/standalone/.env.example
- `/home/e/dev/misc/openseo` branches `docs/issue-1-password-coolify`, `fix/issue-1-password-auth`
- GitHub issue https://github.com/enesbala5/openseo/issues/1

## As-built (2026-11-21)

- Old app `x1bljvfwswxr1zehhdyunljz` remains stopped and domain mapping cleared in DB (`docker_compose_domains = {}`); its volume and backups are retained.
- New Coolify **service** `rq7d0gbesp454h1aquvfb6un` ("OpenSEO Auth") runs upstream `open-seo-standalone:v0.1.27` (pinned digest), 5 containers: storage, runtime, init (exited 0), crawl-gateway, web.
- Env transferred privately from the old deployment; `AUTH_MODE=password`, `BETTER_AUTH_URL=https://openseo.enesbala.com`, generated `STORAGE_SECRET_KEY`, `OPENSEO_IMAGE` pinned. `BETTER_AUTH_SECRET` was deliberately not set (generated in the `config` volume).
- Backups: `/home/e/openseo-migration/backup-20261121T163339Z/` (sha256 `923e5344…218045`) and `backup-postmigration-20261121T163827Z/` (sha256 `7f52e8d4…470a8c`) on `home-server`.
- Export: `/home/e/openseo-migration/export-20261121T163900Z/` — 5,977 DB rows, 25 artifacts, 2 projects (Portfolio, Coverlttr), 1 user, 7 audits.
- Admin `contact@enesbala.com` claimed via `claim-legacy-user local-admin … delegated-local-admin`. Generated password stored mode 0600 at `/home/e/openseo-migration/admin-password` on `home-server` (copy at `/tmp/opencode/admin-password`, also 0600).
- Proxy: the custom dynamic Caddy config `/dynamic/openseo.caddy` (host path `/data/coolify/proxy/caddy/dynamic/openseo.caddy`) was changed from `reverse_proxy open-seo:3001` to `reverse_proxy web-rq7d0gbesp454h1aquvfb6un:80`; proxy restarted. This is the durable fix — earlier attempts to clear the old app's domain did not change this file.
- Verification: public `/` 200, `/api/health` reports `version 0.1.27`, `authMode password`; UI shows sign-in page and registration is closed; anonymous and fake `oseo_` `/mcp` calls return 401; authenticated `/mcp` `whoami` returns `contact@enesbala.com`; `list_projects` returns Portfolio and Coverlttr.
- API key `oseo_…` created in Settings via Better Auth API, stored mode 0600 at `/home/e/openseo-migration/mcp-api-key` on `home-server` and `/tmp/opencode/openseo-mcp-key` locally. Authenticated MCP verified with it.
- Not done: rewiring MCP client configs (`misc/mcp/mcp.json`, `tools/zed/settings.json`, Cursor, GEO CLI) — they currently have no auth and will get 401 until updated with OAuth or the API key. Fork deletion also not done; scope needs confirmation.

### Fork deletion (2026-11-21, post-approval)

- Preserved both branches' docs locally before deletion:
  - `misc/plans/openseo-issue1-runbook.md` (from `docs/issue-1-password-coolify`)
  - `misc/plans/openseo-issue1-rollout.md` (from `fix/issue-1-password-auth`)
- Local clone `/home/e/dev/misc/openseo`: deleted.
- GitHub repo `enesbala5/openseo`: deletion attempted but blocked — token lacks `delete_repo` scope. Owner must run `gh auth refresh -h github.com -s delete_repo`, then `gh repo delete enesbala5/openseo --yes` (or delete via GitHub UI).
