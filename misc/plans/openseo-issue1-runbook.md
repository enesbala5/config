# Password auth for the Coolify deployment

Related issue: <https://github.com/enesbala5/openseo/issues/1>

This documents the upstream-supported path to remove public `local_noauth`
access from the existing Coolify deployment. It uses upstream's prebuilt standalone image
and its one-time legacy importer. It does not update this fork's application
source.

Production has not been changed by this document. Live Coolify settings below remain unverified until the operator checks them.

## What is verified

On 2026-11-14, the public endpoint reported OpenSEO `0.1.14` with
`authMode: local_noauth`. Anonymous `/mcp` initialization and a `tools/list`
request with a fake `oseo_` bearer both succeeded.

The checked-in deployment cannot be fixed by changing a Coolify environment variable:

- The current [`compose.yaml`](../compose.yaml) fixes
  `AUTH_MODE=local_noauth` in the container environment. Coolify's environment
  variables cannot override an explicit Compose value.
- The current [`auth-mode.ts`](../src/lib/auth-mode.ts) has no `password` mode.
  A set value of `password` is invalid in `0.1.14`, and the runtime falls back
  to `cloudflare_access`.
- Password mode was added in upstream v0.1.17. It is present in the verified
  v0.1.27 release source.

The small operational resolution is:

1. Keep the old volume.
2. Move its data into upstream's standalone stack with the provided importer.
3. Use `AUTH_MODE=password` and the standalone image.
4. Claim the imported `local-admin` account before restoring the public domain.

No application, Compose, dependency, or migration change is required in this fork.

The legacy image `ghcr.io/every-app/open-seo:v0.1.27` shares the newer source
and can recognize the mode, but upstream still publishes and documents that
image as a no-sign-in deployment. Its Compose fixes
`AUTH_MODE=local_noauth`, and it has no standalone initializer or generated
operator configuration. Use it only as the import source. Do not try to turn it
into the final password deployment.

## Prerequisites

Choose these before starting:

- The admin email to attach to the imported `local-admin` user.
- A new 8 to 128 character admin password, stored in a password manager.
- A new `STORAGE_SECRET_KEY`, at least 32 random characters.
- A backup location outside the Docker volume.
- A private maintenance window. Finish running audits, rank checks, and SAM replies first.

The deployment server needs enough memory for the standalone stack, preferably
4 GiB or more. The importer also builds the upstream migration target from its
v0.1.27 source.

Do not set `BETTER_AUTH_SECRET` for the standalone stack. Upstream's verified
v0.1.27 `configure.mjs` creates `BETTER_AUTH_SECRET`,
`OPENSEO_OPERATOR_SECRET`, and `CRAWL_GATEWAY_SECRET` in the persistent `config`
volume on first start. A shell environment value does not replace those
generated secrets.

Do not set `AUTH_MODE=password` on the old OpenSEO application. It has neither
the standalone initializer nor the standalone secret volume.

## 1. Close the public route

Block `openseo.enesbala.com` at the reverse proxy or firewall during maintenance.
Do not rely on removing DNS or disabling Cloudflare proxying: cached DNS and
direct-origin access can still reach the server. Record the current routing
settings before changing them.

Before stopping the old application, record its writable data volume:

```sh
docker inspect openseo --format '{{range .Mounts}}{{if eq .Destination "/app/.wrangler"}}{{.Name}}{{end}}{{end}}'
```

In Coolify application `x1bljvfwswxr1zehhdyunljz`:

1. Set auto deploy to manual or disable it.
2. Remove the application's public domain assignment.
3. Stop the application without deleting its volumes.

From a network outside the server, confirm the hostname no longer reaches OpenSEO before continuing.

## 2. Back up and prepare the legacy volume

Run these commands as root on the Coolify deployment server. Verify that the
live container is named `openseo`, as the checked-in Compose file specifies.
If Coolify removed that container when stopping, use the volume name recorded
in step 1 instead of repeating `docker inspect`. Take the archive only while
the application is stopped; do not guess the Compose project prefix.

```sh
legacy_volume="$(docker inspect openseo --format '{{range .Mounts}}{{if eq .Destination "/app/.wrangler"}}{{.Name}}{{end}}{{end}}')"
test -n "$legacy_volume"
printf 'Legacy volume: %s\n' "$legacy_volume"

legacy_mount="$(docker volume inspect "$legacy_volume" --format '{{.Mountpoint}}')"
install -d -m 700 /root/openseo-backups
umask 077
backup="/root/openseo-backups/legacy-before-upgrade-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
tar --numeric-owner -C "$legacy_mount" -czf "$backup" .
sha256sum "$backup"
```

Keep both the backup and its SHA-256 digest off the server as well as on it. The archive contains user data and credentials.

Update only the old application's image setting. The digest pins the verified
multi-platform v0.1.27 index:

```text
OPEN_SEO_IMAGE=ghcr.io/every-app/open-seo:v0.1.27@sha256:ce005c175150993bade99e7e11c12ac861e5ab85cf42198f5c405eb4d27b7ec4
```

Deploy the old application while the public route remains closed. Wait for
health to report version `0.1.27`, then let any schema work settle. Stop the
application again without deleting anything.

Take a second archive now, using `legacy-after-upgrade` in the filename. Keep
the pre-upgrade archive for rollback to `0.1.14`.

## 3. Create the standalone deployment

In the same Coolify project and environment, create a new application from the
public `https://github.com/every-app/open-seo` repository.

Use these source settings:

```text
Build strategy: Docker Compose
Branch: main
Commit: 4fa42c879fd26657aec3472dcf44f08226816df3
Base directory: /deploy/standalone
Docker Compose location: /compose.yaml
Auto deploy: disabled
```

The commit is the verified v0.1.27 release commit. The image is also pinned, so
Coolify must not deploy upstream `main` from a mutable tag.

Add these environment variables in Coolify. Reuse existing provider values
without copying them into this document or Git:

```text
AUTH_MODE=password
BETTER_AUTH_URL=https://openseo.enesbala.com
OPENSEO_IMAGE=ghcr.io/every-app/open-seo-standalone:v0.1.27@sha256:e0687b1d3aa0671c401ca39c5bbf7b57a478433f17b7ee0169b1c4f72ee5865e
STORAGE_ACCESS_KEY=openseo
STORAGE_SECRET_KEY=<new unique random value>
LEGACY_VOLUME=<the exact legacy_volume value printed above>
DATAFORSEO_API_KEY=<existing value>
```

Copy any existing `OPENROUTER_API_KEY`, `OPENROUTER_BASE_URL`,
`OPENROUTER_MODEL`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`,
`GOOGLE_MAPS_API_KEY`, `CONTEXT_API_KEY`, and `CRAWLER_ACCESS_SECRET` values
that the deployment actually uses. Leave unset values unset.

Do not add a domain yet. Do not publish `storage`, `runtime`, or
`crawl-gateway`. The only public service will be `web` on port `80`.

## 4. Run the one-time import

**Deployment checkpoint:** verify how your installed Coolify version combines
upstream's `compose.yaml` and `compose.migrate.yaml` before deploying. This
integration has not been tested on your instance. Do not replace Coolify's
start command with a raw `docker compose -f ...` command: doing so can bypass
its generated Compose configuration, environment files, proxy labels and
project/volume settings.

Upstream's documented shell-managed migration uses both Compose files:

```sh
# Upstream reference, NOT a replacement for Coolify's generated start command.
docker compose -f deploy/standalone/compose.yaml \
  -f deploy/standalone/compose.migrate.yaml up -d --build
```

For Coolify, confirm its parsed/generated deployment includes `migrate`, its
build context, the existing external legacy volume, the new stack's shared
`config` volume, and the `web` dependency on successful migration. Preserve
Coolify's generated environment and project settings. If the installed version
cannot do this safely, stop here and adapt the integration before importing;
do not create another shell-managed stack with unrelated volumes.

See [Coolify Compose commands](https://coolify.io/docs/applications/builds/docker-compose#application-compose-commands).
Once this integration is verified, deploy once and follow the `migrate` logs. Success ends with the imported row counts and:

```text
Import complete.
```

Do not open the UI while the import is active. The verified importer mounts the legacy volume read-only, refuses a non-empty target database, records completion in the `config` volume, and makes repeated starts a no-op.

After success, return to the base standalone Compose definition, preserving the
same project name and volumes. Restart `runtime` once so imported SAM
conversation histories are loaded.

The importer carries projects, saved keywords, rank trackers and history, audits, reports, and SAM conversations. It does not carry Google connections, sessions, API keys, OAuth grants, MCP connections, provider caches, or in-flight work. Review schedules after import; do not start new paid work.

## 5. Claim the existing admin

Use the Coolify web terminal for the new `runtime` container. This avoids putting the password in shell history or command arguments.

```sh
printf 'Admin email: '
IFS= read -r admin_email
printf 'Admin password (8-128 characters): '
stty -echo
IFS= read -r admin_password
stty echo
echo
printf '%s\n' "$admin_password" | node /opt/standalone/admin.mjs claim-legacy-user local-admin "$admin_email" delegated-local-admin
unset admin_password admin_email
```

Success prints:

```text
claim-legacy-user succeeded for <email>
```

This claims the imported `local-admin` user and `delegated-local-admin` organization. Their IDs are defined by the checked-in `local_noauth` resolver and are therefore stable for this deployment.

Do not use first-visitor signup or `create-user`. Either creates a replacement account instead of attaching credentials to the user that owns Coverlttr and Portfolio. If the claim returns a not-found error, leave the domain closed, inspect the import logs and volumes, and do not delete or replace the data.

## 6. Verify privately

The standalone `web` service publishes only on the server loopback at port `3001`.

```sh
curl -fsS http://127.0.0.1:3001/api/health \
  | jq '{version, authMode, auth: .checks.auth}'
```

Require `version` `0.1.27`, `authMode` `password`, and an auth status of `ok`.

Run both negative MCP probes. Each must return `401` or `403`, not project data and not `admin@localhost`.

```sh
curl -sS -o /dev/null -w 'anonymous: %{http_code}\n' \
  http://127.0.0.1:3001/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"whoami","arguments":{}}}'

curl -sS -o /dev/null -w 'fake key: %{http_code}\n' \
  http://127.0.0.1:3001/mcp \
  -H 'Authorization: Bearer oseo_invalid' \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"whoami","arguments":{}}}'
```

If either probe succeeds, keep the domain closed.

## 7. Restore the domain and check acceptance

In the new Coolify application, add this domain:

```text
https://openseo.enesbala.com
Service: web
Internal port: 80
```

Remove the temporary proxy/firewall maintenance block only after the private
checks and admin claim pass. Keep the old application stopped and without a
domain.

Check the public route:

```sh
curl -fsS https://openseo.enesbala.com/api/health \
  | jq '{version, authMode, auth: .checks.auth}'

curl -sS -o /dev/null -w 'anonymous: %{http_code}\n' \
  https://openseo.enesbala.com/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"whoami","arguments":{}}}'

curl -sS -o /dev/null -w 'fake key: %{http_code}\n' \
  https://openseo.enesbala.com/mcp \
  -H 'Authorization: Bearer oseo_invalid' \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  --data '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"whoami","arguments":{}}}'
```

Then use a private browser session:

1. Open `https://openseo.enesbala.com` and confirm project pages redirect to email/password sign-in.
2. Sign in with the claimed admin account.
3. Confirm Coverlttr and Portfolio still exist and their saved data is readable.
4. In Settings, create an API key named `coverlttr-geo`. The full `oseo_` key is shown once.

The first visitor cannot become a second administrator because the imported admin already exists and standalone registration is closed after that.

## 8. Connect Coverlttr and MCP clients

Store the key on the Coverlttr host without printing it:

```sh
install -d -m 700 /root/.config/coverlttr
umask 077
printf 'oseo_ API key: '
stty -echo
IFS= read -r oseo_key
stty echo
echo
printf '%s\n' "$oseo_key" > /root/.config/coverlttr/openseo-mcp-token
unset oseo_key
```

Set:

```text
OPENSEO_MCP_URL=https://openseo.enesbala.com/mcp
OPENSEO_MCP_TOKEN_FILE=/root/.config/coverlttr/openseo-mcp-token
```

Reconnect Cursor to the same `/mcp` URL with OAuth or the API key. Old Cursor sessions, OAuth grants, and old API keys were not imported.

Use read-only checks first: `whoami`, `list_projects`, and `get_project_context` for Coverlttr. Do not run keyword research, SERP, audit, or other billable tools as part of the auth cutover.

## Rollback

Keep the domain closed during rollback.

If the import or claim fails, stop the new application without deleting its volumes. Restart the old application on the verified v0.1.27 legacy image with its original domain removed. It is still `local_noauth`, so never expose it.

The original legacy volume remains available because the importer mounts it read-only and neither stack should use `down -v`. The pre-upgrade archive is the fallback if the old volume is damaged. Writes made after the move live only in the standalone `storage` and `runtime` volumes and are not copied back automatically.

Never delete the legacy volume, the standalone `config` volume, or the standalone `storage` volume to fix a failed migration. If the legacy volume ran v0.1.27 migrations, restoring the `0.1.14` image may require the pre-upgrade archive and a fresh volume.

## Validation and remaining uncertainty

Checked:

- Public `/api/health` reports `0.1.14` and `local_noauth`.
- Anonymous `/mcp` initialization returns a server response.
- Current checkout auth modes exclude `password`.
- Root Compose hardcodes `local_noauth`.
- Upstream v0.1.27 release source and published tags contain the standalone stack, password mode, generated secret file, importer, account claim command, and MCP API-key path.
- Upstream legacy docs still define the old image as a no-sign-in deployment.
- Upstream v0.1.17 release notes record the introduction of self-hosted email/password accounts.
- Upstream Coolify and persistent-storage guidance matches the Compose-owned volume and service-domain instructions above.

Not checked:

- The live Coolify source branch, commit, image value, environment names, domain assignments, volume name, available memory, and backup settings.
- Any production import, account claim, authenticated Coverlttr read, browser login, DNS change, API key creation, or MCP reconnect.
- Image tests or a trial migration. The v0.1.27 source and published image metadata were checked, but this document does not execute either.

Primary references:

- [Upstream v0.1.17 release](https://github.com/every-app/open-seo/releases/tag/v0.1.17)
- [Upstream standalone Compose, v0.1.27](https://github.com/every-app/open-seo/blob/v0.1.27/deploy/standalone/compose.yaml)
- [Upstream standalone Docker guide, v0.1.27](https://github.com/every-app/open-seo/blob/v0.1.27/docs/SELF_HOSTING_DOCKER.md)
- [Upstream legacy Docker guide, v0.1.27](https://github.com/every-app/open-seo/blob/v0.1.27/docs/SELF_HOSTING_DOCKER_LEGACY.md)
- [Upstream legacy importer, v0.1.27](https://github.com/every-app/open-seo/blob/v0.1.27/scripts/celld/migrate-legacy.mjs)
- [Coolify Docker Compose](https://coolify.io/docs/applications/builds/docker-compose)
- [Coolify environment variables](https://coolify.io/docs/services/configuration/environment-variables)
- [Coolify persistent storage](https://coolify.io/docs/services/configuration/persistent-storage)
- [Coolify web terminal](https://coolify.io/docs/core/infrastructure/servers/web-terminal)
