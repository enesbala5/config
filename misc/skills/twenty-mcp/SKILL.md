---
name: twenty-mcp
description: Use when reading or reporting on the Twenty workspace.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [twenty, crm, mcp, reporting, data, coverlttr]
    related_skills: [hermes-cron-pipelines]
---

# Twenty workspace over MCP

## When to Use

Use when a task reads or writes data in Enes's self-hosted Twenty workspace (the Coverlttr CRM) through the `Twenty` MCP server — ad-hoc questions about users, cover letters, job listings, purchases or referrals, bot routines that touch the CRM, recurring recap jobs, and dashboards built from workspace counts.

Not for: building the scheduled job itself (see `hermes-cron-pipelines`) or non-Twenty data sources.

## Reaching the tools

- Config is `mcp_servers.Twenty` in the target profile's `config.yaml`. Servers are per-profile: a CLI session started under a different profile answers for that profile's list, so check which profile you are in before concluding a server is unconfigured.
- Three-step access: `mcp__Twenty__get_tool_catalog` → `mcp__Twenty__learn_tools` (batch every tool name you need into one call) → `mcp__Twenty__execute_tool`. Catalog and schema dumps are very large and spill to `~/.hermes/cache/spillover/` — page that file with `read_file`, never re-request the same data from the server.
- One tool per object per verb: `find_many_<plural>`, `group_by_<plural>`, `find_one_<singular>`, `create_/update_/upsert_/delete_`. MCP invocations cannot be batched — N metrics is N calls, so plan the call list before starting.

## Object map

- **Person** (`people`) — the product's users. `lifecycleStage` (free text: `REGISTERED` / `ACTIVATED` / `SUBSCRIBED`, where ACTIVATED means a cover letter exists), `onboardingStatus` (PENDING/COMPLETED/SKIPPED), `signupSource`, `referredById`, `coverlttrUserId`, `creditsBalance`, `subscriptionPlan/Status/Period`, `currentPeriodEnd`, `lastApplicationDate`, plus acquisition fields (browser, deviceType, country, referrer, ipAddress, userAgent).
- **Cover Letter** (`applications`) — one row per generated letter: `applicantId`, `employerName`, `jobTitle`, `applicationStage`, `acquisitionSource`, `generationCount`, `targetRoleUrl`.
- **Job Listing** (`job_listings`) — `source` = `MANUAL` | `CHROME_EXTENSION` | `LINKEDIN_COPY_PASTE`, `savedById`, `converted`, `linkedinUrl`, `positionTitle`, `companyName`.
- **Purchase** (`purchases`) — `amount` (currency composite), `status`, `purchaseType`, `purchasePlan`, `period`, `occurredAt`, `creditsAdded`, `fromReferral`.
- **Company**, **Newsletter Subscriber**, **Onboarding Response**, **Referral Reward** (`referrerUserId`, `referredUserId`, `creditsGranted`, `collected`), **Note**, **Task** (`status`, `dueAt`), **Timeline Activity** (`happensAt`, `target*Id`).

## Query recipes

Daily counts — the workhorse:

```json
{"groupBy":[{"createdAt":{"granularity":"DAY","timeZone":"Europe/Tirane"}}],"limit":100,"aggregateOperation":"COUNT"}
```

Returns groups of `{dimensions:["YYYY-MM-DD"], value:"n"}` with the count as a string. A date with no bucket is zero; a day's total is the sum of that date's buckets. Buckets come back ordered by aggregate value, not by date, so look dates up by value and never by position.

Daily split in the same call — two dimensions maximum, and the date goes first:

```json
{"groupBy":[{"createdAt":{"granularity":"DAY","timeZone":"Europe/Tirane"}},{"lifecycleStage":true}],"limit":100,"aggregateOperation":"COUNT"}
```

The second dimension can be `null` for records with no value set — those are real rows, not errors. Non-date questions reuse the same shape with the attribute first: `{"groupBy":[{"source":true}]}`.

Find and filter:

- Filters are top-level argument keys, never wrapped in a `filter` object: `{"select":["id","name"],"createdAt":{"gte":"..."}}`. `select` is required; `"*"` returns everything; `and`/`or`/`not` combine.
- **`createdAt` and `updatedAt` are groupable but not always filterable.** Many objects expose no date filter at all, so "how many were created yesterday" is a grouped-bucket lookup, not a `find_many` with a range. Check the object's filter fields before promising a range query.
- `limit` caps at 100 on both find and group. When `hasNextPage` is true, or `count` exceeds the page, paginate with `offset` before answering any count or enumeration question.

## Field quirks that cost calls

- **Aggregates are not available on every field.** `COUNT_NOT_EMPTY` is rejected on relation fields (`No aggregation available for COUNT_NOT_EMPTY on field "referredById"`). To count non-null relations, group by the relation and sum the buckets whose dimension is not null.
- **`SUM` on a currency composite returns 0.** `amount` is a composite, so `SUM(amount)` groups to zero while rows exist; count the rows, and read amounts from `find_many_purchases` when a real total is needed.
- **The same fact often lives in two objects.** New referred users = `people` grouped by `createdAt` × `referredById`; the `referral_rewards` object is a separate, sparser ledger that can be near-empty while referral signups exist. The job-listings "source" split is per listing, while "how many users saved one" is per distinct `savedById`. State which one a report means instead of blending them.
- **Verify an object is populated before promising a metric from it.** `tasks` and `onboarding_responses` can be empty while the rest of the workspace is busy; a report line built on an empty object reads zero forever. Flag it in the reply rather than shipping it silently.
- `lifecycleStage` is free text written by the app, not a select field: group by it and read the actual values instead of assuming an enum, and expect a null group.
- Read select-field options and field types from `get_field_metadata` (e.g. `{"objectName":"person"}`) when a report needs to name a bucket.

## Writing back

`create_*`, `update_*`, `upsert_*` and `delete_*` mutate the user's live CRM. Only act on an explicit instruction that names the object and the change, and report the affected record id back. Reporting and recap jobs stay read-only.
