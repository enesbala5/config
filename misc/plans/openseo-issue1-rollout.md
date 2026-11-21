# Password-auth rollout for the fork

Related issue: https://github.com/enesbala5/openseo/issues/1

The root `compose.yaml` now runs upstream's standalone `0.1.27` image. It forces `AUTH_MODE=password`, even if Coolify still has `AUTH_MODE=local_noauth`. This is a different storage format from the old single-container image; deploying the new file alone will show an empty installation, not the existing projects.

Do not auto-deploy this branch onto the public hostname. Keep the hostname blocked at the proxy until the import, admin claim and checks below are complete. The first visitor can create an administrator on an unclaimed installation.

## 1. Prepare a private maintenance window

In Coolify app `x1bljvfwswxr1zehhdyunljz`, disable automatic deployment and block public access at the reverse proxy. Wait for running audits, rank checks and SAM replies to finish. Do not run paid research as part of this rollout.

Record the current Compose project name, image digest, environment and volume name. Keep the same Compose project name throughout the move. Find the actual legacy volume, rather than assuming its prefix:

```sh
docker inspect openseo --format '{{range .Mounts}}{{if eq .Destination "/app/.wrangler"}}{{.Name}}{{end}}{{end}}'
```

The original deployment file is retained as `compose.legacy.yaml`. Stop the old app and take an offline backup/snapshot of its legacy volume before upgrading it. Save the original environment and image digest securely as well. Then, on the deployment host from this checkout, update the old installation once using upstream's legacy image, with public access still blocked:

```sh
export COMPOSE_PROJECT_NAME='<existing Coolify Compose project name>'
export LEGACY_VOLUME='<volume name from docker inspect>'
OPEN_SEO_IMAGE=ghcr.io/every-app/open-seo:0.1.27 docker compose -f compose.legacy.yaml pull
OPEN_SEO_IMAGE=ghcr.io/every-app/open-seo:0.1.27 docker compose -f compose.legacy.yaml up -d
```

Confirm the old app starts and finishes its database migrations. Stop the old stack with `docker compose -f compose.legacy.yaml down` (no `-v`). Make a second offline backup/snapshot after this update, before proceeding with the import. Retain the pre-upgrade backup for rollback to the original image. Never delete the original volume during this rollout.

## 2. Configure the standalone stack

Set these values in Coolify's environment, without committing credentials:

- `BETTER_AUTH_URL=https://openseo.enesbala.com`
- `STORAGE_ACCESS_KEY=openseo` and a unique, strong `STORAGE_SECRET_KEY`
- Existing `DATAFORSEO_API_KEY` and any optional provider credentials
- `LEGACY_VOLUME` set to the volume recorded above (for the import only)

Remove obsolete `OPEN_SEO_IMAGE` and `AUTH_MODE=local_noauth` overrides. The new image override is `OPENSEO_IMAGE`; it defaults to `ghcr.io/every-app/open-seo-standalone:0.1.27`.

Unlike the legacy deployment, upstream standalone creates a 64-character random `BETTER_AUTH_SECRET` inside the persistent `config` volume on its first start. Setting `BETTER_AUTH_SECRET` in Coolify does not override that file. Back up `config` along with the storage volume; it also holds the operator secret. Do not print those secrets or rotate them during migration. Old Google tokens and sessions are not imported.

Configure Coolify to use root `compose.yaml` plus `compose.migrate.yaml` for the first deployment. The migration service builds this checkout, so allow the build time and at least 4 GiB of host memory. Keep its environment private. From a shell on the deployment host, the equivalent is:

```sh
docker compose -f compose.yaml -f compose.migrate.yaml pull --ignore-buildable
docker compose -f compose.yaml -f compose.migrate.yaml up -d --build
docker compose -f compose.yaml -f compose.migrate.yaml logs -f migrate
```

Do not run another Compose project against the same legacy volume while the old app is active. The importer mounts it read-only and records completion in `config`; restarting the migration service after success is a no-op. `web` cannot start until the import succeeds.

The migration copies projects, keywords, trackers/history, audits, reports and SAM conversations. It does not copy Google connections, sessions, API keys, MCP connections, provider caches or in-flight work. Review schedules after import; do not enable new AI visibility schedules.

## 3. Claim the imported administrator

Do not register a fresh first-visitor account. Claim the imported `local-admin` account and its `delegated-local-admin` organization, preserving ownership of Coverlttr and Portfolio. On the deployment host, use Bash to keep the password out of shell history:

```bash
read -r -p 'Admin email: ' admin_email
read -rs -p 'Admin password (8–128 characters): ' password; echo
printf '%s\n' "$password" | docker compose exec -T runtime \
  node /opt/standalone/admin.mjs claim-legacy-user \
  local-admin "$admin_email" delegated-local-admin
unset password admin_email
```

The CLI calls the private operator endpoint using the secret in `config`. If the claim fails, leave the proxy blocked and inspect the error; do not create a replacement account or delete volumes. If the legacy installation used different IDs, inspect the imported data privately and use its actual IDs.

Once the claim succeeds, remove the migration override from Coolify and use root `compose.yaml` alone. Target the domain at service `web`, port **80**, rather than the removed `open-seo` service on port 3001. Only `web` should be proxy-accessible; do not publish storage, runtime or the crawl gateway. Forward WebSocket upgrades for SAM. Keep the hostname blocked until checks are complete.

## 4. Verify before reopening public access

Use a private route or SSH tunnel to the loopback listener for initial checks. If the public origin is required for cookies, allow only your IP temporarily at the proxy.

1. Check `/api/health`: it must report `password`, not `local_noauth`. In a fresh browser session, project pages must require email/password sign-in. After claiming the admin, an unrelated visitor must not be able to register a new account.
2. Send read-only MCP calls with no bearer, then with a fake `oseo_` bearer. Both must return 401/403, never project data or `admin@localhost`. For example, against the loopback listener:

   ```sh
   curl -sS -o /dev/null -w '%{http_code}\n' \
     http://127.0.0.1:3001/mcp \
     -H 'Content-Type: application/json' \
     -H 'Accept: application/json, text/event-stream' \
     --data '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"whoami","arguments":{}}}'
   ```

   Repeat with `-H 'Authorization: Bearer oseo_invalid'`. Also check `list_projects` and `get_project_context` with a known project ID; do not call research tools.

3. Sign in as the claimed account. Confirm the existing Coverlttr and Portfolio projects, reports and saved data remain available. Create an API key from Settings with the intended lifetime, store it privately on the GEO CLI host and set `OPENSEO_MCP_TOKEN_FILE` to that file. Never put the key in Git, the PR, shell history or logs.
4. Reconnect Cursor and other MCP clients through OAuth or the new API key. Verify `whoami`, `list_projects` and Coverlttr's `get_project_context` authenticate as the claimed account. Old OAuth grants and keys do not survive the import.
5. Reopen the public proxy only after these checks pass. Repeat the anonymous/fake-bearer checks against `https://openseo.enesbala.com/mcp`, then record results in issue #1. Keep that issue open until the production acceptance checklist passes.

## Rollback

Keep public access blocked. Stop the standalone stack without `-v`, switch Coolify back to `compose.legacy.yaml`, its original service/port and the recorded legacy environment/image. The original legacy volume is untouched by the importer. Use the matching pre-upgrade backup if restoring the original legacy image. Do not expose this rollback publicly: it restores `local_noauth`. Writes made after the move are in the new storage volume and are not copied back automatically.

Never use `docker compose down -v`, delete the legacy volume or replace the `config` volume to fix a failed migration.
