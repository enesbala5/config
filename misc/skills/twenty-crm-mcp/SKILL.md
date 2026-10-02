---
name: twenty-crm-mcp
description: Query and recap a Twenty CRM workspace via MCP.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [twenty, crm, mcp, reporting, metrics, coverlttr]
    related_skills: [hermes-cron-pipelines]
---

# Twenty CRM over MCP

## When to Use

- Asked for numbers, a dashboard, a recap or a digest out of a Twenty workspace (server name `Twenty`, tools `mcp__Twenty__*`): "how many signups yesterday", "daily activity", "trend", "top plans", "who signed up this week".
- Asked to read, create, update or delete Twenty records for the Coverlttr CRM.
- Wiring or changing the scheduled Twenty recap job — then read this with `hermes-cron-pipelines`.

The workspace on this machine is the Coverlttr CRM — people, cover letters, purchases, newsletter subscribers. The object map and the exact metric recipes are in `references/coverlttr-workspace-metrics.md`.

## Discovery order — never guess a tool name

1. `mcp__Twenty__get_tool_catalog` returns every server tool grouped by category (ACTION, DATABASE_CRUD, METADATA, VIEW, ROLE, WORKFLOW, DASHBOARD). It is very large and spills to a file under `~/.hermes/cache/spillover/` — read the spilled copy and filter it locally instead of calling the catalog again.
2. `mcp__Twenty__learn_tools` with **all** the names you need in one call (`toolNames` takes an array). Schemas are big and spill the same way; request only what you will use.
3. `mcp__Twenty__execute_tool` with `{toolName, arguments}` executes one tool. **One MCP call per invocation** — these do not batch the way connector tools do, so N metrics is N calls. Budget for it.

Per object `X` the family is `find_many_X`, `find_one_X`, `group_by_X`, `create_one_X` / `create_many_X`, `update_*`, `upsert_*`, `delete_*` (delete is a soft delete). The server offers the writes freely — the workspace is the user's real CRM, so "recap", "report", "how many" and "show me" are read-only requests; only an explicit instruction to change data justifies a write.

## Reporting: `group_by_*` is the primitive

For "how many per day / per plan / per stage", use `group_by_<object>` rather than `find_many_<object>` plus a date range. Working arguments for a daily trend:

```json
{"groupBy": [{"createdAt": {"granularity": "DAY", "timeZone": "Europe/Tirane"}}], "limit": 100, "aggregateOperation": "COUNT"}
```

- One call returns **every** bucket, so on a small workspace a single call answers today, yesterday and a seven-day window at once. Read the bucket by its date string: `dimensions[0]` is `YYYY-MM-DD`, `value` is the count as a **string** (coerce before arithmetic).
- `orderBy` on `group_by` sorts by the aggregate value, not by the dimension, and is effectively ignored in practice. **Never read the first or last group as "the latest day"** — look the date up explicitly.
- A missing date is a real zero. Do not skip it when averaging a fixed window, and do not treat absence as an error.
- Grouping by two dimensions is allowed (max 2), and `limit` caps at 100. Other aggregates (`SUM`, `AVG`, `MIN`, `MAX`, `COUNT_UNIQUE_VALUES`, `COUNT_TRUE`, …) need `aggregateFieldName`.

## Gotchas that cost time

- **Filter fields are per object and are not "whatever the record has".** `createdAt` is often absent from an object's top-level filter args, so `find_many_<object>` cannot answer "created since X" there — that case is exactly what the day-bucket `group_by` above is for. Read the object's own filter args before designing a date-ranged query.
- **`SUM` on a currency composite field returns 0** — it is not a scalar column. For money, fetch the records and read the amount values off them.
- `find_many` returns `{records, count, hasNextPage}` with `count` as a **string**; while `hasNextPage` is true, the returned page is not the answer.
- Filters take each field as its own top-level key (`{"id": {"eq": "..."}}`) — never wrapped in a `filter` object, never a bare operator at the top level. Combine with `and` / `or` / `not`; composite fields nest (`{"name": {"firstName": {"ilike": "%a%"}}}`).
- When a result is larger than the inline limit it spills to disk with a path in the footer — page that file, do not re-issue the call.

## Delivery

- A recap is a report, not a data dump: fixed emoji-led skeleton, one fact per line, each number with its previous-period delta and one short trend line. No tables (Discord renders none), no per-day figure dumps, no markdown headers.
- **Do not overengineer the trend.** Enes's standing instruction for this class: a delta against the previous period plus a plain mean over the window is the whole computation — no trend scripts, no rolling models, no query layer.
- State metric limits out loud (a count-only metric because the amount field will not sum, an object with no daily signal) instead of implying coverage you do not have, and never fill a failed call with a plausible number — name the metric as unavailable on its own line.
- The recurring daily version of this report is wired as a cron job; the cache shape, the day-key check and the delivery skeleton live with `hermes-cron-pipelines`.
