---
name: twenty-mcp
description: Use when reading, writing, or recapping the Twenty workspace (Coverlttr CRM), including the daily signup, cover letter, newsletter, and purchase digest.
version: 1.1.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [twenty, crm, mcp, reporting, metrics, data, coverlttr]
    related_skills: [hermes-cron-pipelines]
---

# Twenty workspace over MCP

## When to Use

Use when a task reads or writes data in Enes's self-hosted Twenty workspace (the Coverlttr CRM) through the `Twenty` MCP server — ad-hoc questions about users, cover letters, job listings, purchases or referrals, bot routines that touch the CRM, recurring recap jobs, and dashboards built from workspace counts.

A Coverlttr recap, digest, or "how many yesterday / this week" question follows [the daily metric recipe](references/coverlttr-workspace-metrics.md). Wiring or changing the scheduled job also needs `hermes-cron-pipelines`.

Not for non-Twenty data sources.

## Reaching the tools

- Config is `mcp_servers.Twenty` in the target profile's `config.yaml`. Servers are per-profile: a CLI session started under a different profile answers for that profile's list, so check which profile you are in before concluding a server is unconfigured.
- Three-step access: `mcp__Twenty__get_tool_catalog` → `mcp__Twenty__learn_tools` (batch every tool name you need into one call) → `mcp__Twenty__execute_tool`. Catalog and schema dumps are very large and spill to `~/.hermes/cache/spillover/` — page that file with `read_file`, never re-request the same data from the server.
- One tool per object per verb: `find_many_<plural>`, `group_by_<plural>`, `find_one_<singular>`, `create_/update_/upsert_/delete_` (`delete_*` is a soft delete). MCP invocations cannot be batched — N metrics is N calls, so plan the call list before starting.
- "Recap", "report", "how many", and "show me" are read-only. Only an explicit instruction that names the object and the change justifies a write.

## Object map

- **Person** (`people`) — the product's users. `lifecycleStage` (free text: `REGISTERED` / `ACTIVATED` / `SUBSCRIBED`, where ACTIVATED means a cover letter exists), `onboardingStatus` (PENDING/COMPLETED/SKIPPED), `signupSource`, `referredById`, `coverlttrUserId`, `creditsBalance`, `subscriptionPlan/Status/Period`, `currentPeriodEnd`, `lastApplicationDate`, plus acquisition fields (browser, deviceType, country, referrer, ipAddress, userAgent).
- **Cover Letter** (`applications`) — one row per generated letter: `applicantId`, `employerName`, `jobTitle`, `applicationStage`, `acquisitionSource`, `generationCount`, `targetRoleUrl`.
- **Job Listing** (`job_listings`) — `source` = `MANUAL` | `CHROME_EXTENSION` | `LINKEDIN_COPY_PASTE`, `savedById`, `converted`, `linkedinUrl`, `positionTitle`, `companyName`.
- **Purchase** (`purchases`) — `amount` (currency composite), `status`, `purchaseType`, `purchasePlan`, `period`, `occurredAt`, `creditsAdded`, `fromReferral`.
- **Company**, **Newsletter Subscriber**, **Onboarding Response**, **Referral Reward** (`referrerUserId`, `referredUserId`, `creditsGranted`, `collected`), **Note**, **Task** (`status`, `dueAt`), **Timeline Activity** (`happensAt`, `target*Id`).

Which of these move per day, and the four recap lines, are in the [metrics reference](references/coverlttr-workspace-metrics.md).

## Query recipes

Daily counts — the workhorse:

```json
{"groupBy":[{"createdAt":{"granularity":"DAY","timeZone":"Europe/Tirane"}}],"limit":100,"aggregateOperation":"COUNT"}
```

Returns groups of `{dimensions:["YYYY-MM-DD"], value:"n"}` with the count as a string. Coerce it before arithmetic. A date with no bucket is zero; a day's total is the sum of that date's buckets. `orderBy` sorts by the aggregate value and is effectively ignored, so look dates up by the date string and never by position. On a small workspace one call covers today, yesterday, and a seven-day window.

`timeZone` must be `Europe/Tirane`. A UTC bucket splits the local evening across two days.

Daily split in the same call — two dimensions maximum, and the date goes first:

```json
{"groupBy":[{"createdAt":{"granularity":"DAY","timeZone":"Europe/Tirane"}},{"lifecycleStage":true}],"limit":100,"aggregateOperation":"COUNT"}
```

The second dimension can be `null` for records with no value set — those are real rows, not errors. Non-date questions reuse the same shape with the attribute first: `{"groupBy":[{"source":true}]}`. Other aggregates (`SUM`, `AVG`, `MIN`, `MAX`, `COUNT_UNIQUE_VALUES`, `COUNT_TRUE`) need `aggregateFieldName`.

Find and filter:

- Filters are top-level argument keys, never wrapped in a `filter` object: `{"select":["id","name"],"createdAt":{"gte":"..."}}`. `select` is required; `"*"` returns everything; `and`/`or`/`not` combine. Composite fields nest (`{"name":{"firstName":{"ilike":"%a%"}}}`).
- **`createdAt` and `updatedAt` are groupable but not always filterable.** Many objects expose no date filter at all, so "how many were created yesterday" is a grouped-bucket lookup, not a `find_many` with a range. Check the object's filter fields before promising a range query.
- `find_many` returns `{records, count, hasNextPage}` with `count` as a string. `limit` caps at 100 on both find and group. When `hasNextPage` is true, or `count` exceeds the page, paginate with `offset` before answering any count or enumeration question. A spilled result has a path in the footer — page that file, do not re-issue the call.

## Field quirks that cost calls

- **Aggregates are not available on every field.** `COUNT_NOT_EMPTY` is rejected on relation fields (`No aggregation available for COUNT_NOT_EMPTY on field "referredById"`). To count non-null relations, group by the relation and sum the buckets whose dimension is not null.
- **`SUM` on a currency composite returns 0.** `amount` is a composite, so `SUM(amount)` groups to zero while rows exist; count the rows, and read amounts from `find_many_purchases` when a real total is needed. The daily recap therefore counts purchases and does not report revenue.
- **The same fact often lives in two objects.** New referred users = `people` grouped by `createdAt` × `referredById`; the `referral_rewards` object is a separate, sparser ledger that can be near-empty while referral signups exist. The job-listings "source" split is per listing, while "how many users saved one" is per distinct `savedById`. State which one a report means instead of blending them.
- **Verify an object is populated before promising a metric from it.** `tasks` and `onboarding_responses` can be empty while the rest of the workspace is busy; a report line built on an empty object reads zero forever. Flag it in the reply rather than shipping it silently.
- `lifecycleStage` is free text written by the app, not a select field: group by it and read the actual values instead of assuming an enum, and expect a null group.
- Read select-field options and field types from `get_field_metadata` (e.g. `{"objectName":"person"}`) when a report needs to name a bucket.

## Coverlttr daily recap

Follow [references/coverlttr-workspace-metrics.md](references/coverlttr-workspace-metrics.md) for the four calls (`people`, `applications`, `newsletter_subscribers`, `purchases`), the cache at `/root/.hermes/data/twenty-daily/activity.json`, and how to add a metric.

Delivery, once the numbers exist:

- A recap is a report, not a data dump: fixed emoji-led skeleton, one fact per line, each number with its previous-period delta and one short trend line. No tables (Discord renders none), no per-day figure dumps, no markdown headers.
- The trend is a delta against the previous period plus the plain mean over the seven calendar days ending on the previous day. Missing days count as zero. No trend scripts, no rolling models, no query layer.
- State a metric limit on its own line (purchases are a count because `amount` will not sum; an object with no daily signal). A failed call is "unavailable". Never fill it with a plausible number.

The recurring job's day-key check and message skeleton live with `hermes-cron-pipelines`. The prompt file next to the cache is `/root/.hermes/data/twenty-daily/job-prompt.md`.

## Writing back

`create_*`, `update_*`, `upsert_*` and `delete_*` mutate the user's live CRM. Only act on an explicit instruction that names the object and the change, and report the affected record id back. Reporting and recap jobs stay read-only.
