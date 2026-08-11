# Twenty CRM (Self-Hosted) — Backup Requirements

## Summary

Twenty's system of record is **PostgreSQL** — records, schema, custom objects, workflows, views, roles, and (if `IS_CONFIG_VARIABLES_IN_DB_ENABLED=true`) config variables all live there. File attachments live separately in a storage volume. A complete backup needs three things: the Postgres data, the file storage volume, and your `.env` secrets. None of these are optional — missing any one leaves you with a CRM you can't fully restore.

---

## 1. What to back up

### 1.1 PostgreSQL volume/database — required
This is the core of the backup. It contains:
- All records (People, Companies, Opportunities, custom objects)
- Full schema: custom objects, fields, relations
- Workflows and their steps/triggers
- Saved views and filters
- Roles and permissions
- Config variables (if stored in DB rather than only `.env`)

**How to back it up:**

Preferred — logical dump (portable across Postgres minor versions, easy to restore selectively):
```bash
docker exec twenty-postgres pg_dump -U postgres twenty > backup_$(date +%Y%m%d).sql
```

Run on a schedule via cron:
```bash
0 2 * * * docker exec twenty-postgres pg_dump -U postgres twenty > /backups/twenty_$(date +\%Y\%m\%d).sql
```

Alternative — raw volume snapshot (faster, but ties you to the exact Postgres image/version used):
```bash
docker run --rm -v db_data:/volume -v $(pwd)/backups:/backup alpine \
  tar czf /backup/db_data_$(date +%Y%m%d).tar.gz -C /volume .
```
(Volume name varies by compose file — commonly `db_data`, `db-data`, or `pgdata`. Check `docker volume ls`.)

A `pg_dump` is generally the safer default: it's human-readable, restorable into a fresh Postgres instance regardless of version drift, and lets you selectively restore tables if needed.

### 1.2 File storage volume — required
Attachments, uploaded files, and images are stored on disk, not in Postgres. This is a **separate volume** from the database and is easy to forget.

Common mount points depending on your compose file:
- `server-local-data:/app/packages/twenty-server/.local-storage`
- `twenty_data:/app/.local-storage`
- `twenty-server-local-data:/app/packages/twenty-server/${STORAGE_LOCAL_PATH}`

Back it up as a straightforward volume snapshot:
```bash
docker run --rm -v server-local-data:/volume -v $(pwd)/backups:/backup alpine \
  tar czf /backup/file_storage_$(date +%Y%m%d).tar.gz -C /volume .
```

> If you've configured `STORAGE_TYPE` to use S3 or another external object store instead of local disk, back that bucket up through its own mechanism (e.g., S3 versioning/replication) — it won't be in a Docker volume at all.

### 1.3 Environment secrets (`.env`) — required
These live outside both volumes, so a database/file backup alone will **not** capture them. Losing them breaks the restored instance even if the data is intact:

- `APP_SECRET`
- `ACCESS_TOKEN_SECRET`
- `LOGIN_TOKEN_SECRET`
- `REFRESH_TOKEN_SECRET`
- `FILE_TOKEN_SECRET`
- `PG_DATABASE_PASSWORD` / `PG_DATABASE_URL`
- `SERVER_URL` / `FRONT_BASE_URL`
- Any AI provider keys you've configured (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, etc.)

Store this file (or its values, in a secrets manager) alongside your backups — encrypted at rest, since it contains live credentials.

---

## 2. What NOT to bother backing up

- **Redis** — pure cache and background job queue, not source of truth. Nothing durable lives here. Worst case from skipping it: an in-flight workflow job or two lost, which reruns or gets re-triggered on next event. Not worth including in a backup rotation.
- **Container images** — `docker-compose.yml` + `TAG` pin is enough to redeploy the same version; you don't need to archive the images themselves, just note the tag you're running.
- **Node modules / build artifacts** — nothing stateful lives here; a fresh `docker compose pull` / `up` regenerates them.

---

## 3. Important notes

- **Version matching matters.** Restore a `pg_dump` into the same (or compatible) Twenty version it was taken from, or run `ENABLE_DB_MIGRATIONS=true` on restore so Twenty's migrations can bring the schema up to date. Restoring an old dump onto a much newer Twenty version without letting migrations run can leave the schema inconsistent.
- **Secrets must match between backup and restore environment.** If you spin up a new instance and restore the DB/volume without also carrying over `APP_SECRET` and the token secrets, existing sessions won't validate and signed file URLs (protected by `FILE_TOKEN_SECRET`) will break — even though the underlying files are present.
- **Attachments and DB must be backed up together, or close to it.** A DB dump taken at 2am and a file-storage snapshot taken separately at a different time can drift — e.g., a record referencing a file uploaded after your file-storage snapshot but before your DB dump. Run both backup steps back-to-back in the same job.
- **Test restores, not just backups.** A backup you haven't restored at least once isn't verified. Periodically spin up a throwaway stack and confirm the dump + file volume + `.env` actually produce a working instance.
- **`docker exec pg_dump` requires the postgres container to be running and healthy** — it won't work mid-crash-loop. If you need backups even when the stack is unhealthy, back up the Postgres volume directly instead (raw snapshot) as a fallback path.
- **Encrypt backups at rest**, especially since the `.env` secrets and the DB dump together are enough to fully impersonate/access the instance.
- **Retention:** keep enough daily dumps to cover your realistic detection window for bad data (accidental bulk delete, bad workflow run) — e.g., 7–14 daily + a handful of weekly/monthly, adjusted to your risk tolerance.

---

## 4. Quick reference — daily backup script skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail

DATE=$(date +%Y%m%d)
BACKUP_DIR=/backups/twenty
mkdir -p "$BACKUP_DIR"

# 1. Database dump
docker exec twenty-postgres pg_dump -U postgres twenty > "$BACKUP_DIR/db_$DATE.sql"

# 2. File storage volume
docker run --rm -v server-local-data:/volume -v "$BACKUP_DIR":/backup alpine \
  tar czf "/backup/files_$DATE.tar.gz" -C /volume .

# 3. Env/secrets (encrypt this before storing off-host)
cp .env "$BACKUP_DIR/env_$DATE.bak"

# 4. Prune backups older than 14 days
find "$BACKUP_DIR" -type f -mtime +14 -delete
```

Adjust volume names to match your actual `docker-compose.yml` (`docker volume ls` to confirm).
