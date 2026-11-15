# Coverlttr workspace — objects, daily signal, and the metric recipe

Twenty workspace at `https://twenty.enesbala.com/mcp` (server name `Twenty`, tools `mcp__Twenty__*`). It is the Coverlttr CRM: the product's user and revenue objects have been mapped onto Twenty objects with `coverlttr*` id fields.

## Object map

| Called | Object | Carries daily signal |
|---|---|---|
| People | `people` | yes — signups, plus per-user fields: `subscriptionPlan` (STARTER/PRO/AGENCY), `subscriptionStatus`, `lifecycleStage`, `onboardingStatus` (PENDING/COMPLETED/SKIPPED), `signupSource`, `creditsBalance`, `country`, `deviceType`, `browser`, `operatingSystem` |
| Cover Letters | `applications` | yes — cover letters generated; `employerName`, `jobTitle`, `applicationStage`, `acquisitionSource`, `generationCount`, `applicantId` |
| Newsletter Subscribers | `newsletter_subscribers` | yes — low volume |
| Purchases | `purchases` | thin — `amount`, `status`, `purchaseType`, `purchasePlan`, `occurredAt`, `purchaserId`, `fromReferral` |
| Companies | `companies` | no |
| Job Listings | `job_listings` | no |
| Referral Rewards | `referral_rewards` | as needed |
| Onboarding Responses | `onboarding_responses` | empty at time of writing — confirm before adding it as a metric |
| Tasks / Notes | `tasks` / `notes` | CRM housekeeping, not product activity |
| Timeline Activities | `timeline_activities` | audit trail of record changes (`happensAt`, `workspaceMemberId`), useful for "what changed" rather than "how many new" |

The four metrics that make a sensible daily recap: `people` (signups), `applications` (cover letters), `newsletter_subscribers`, `purchases`.

## The daily metric call

One call per metric, pinned to the workspace's local day:

```json
{"toolName": "group_by_people",
 "arguments": {"groupBy": [{"createdAt": {"granularity": "DAY", "timeZone": "Europe/Tirane"}}],
               "limit": 100, "aggregateOperation": "COUNT"}}
```

Swap the tool name for `group_by_applications`, `group_by_newsletter_subscribers`, `group_by_purchases`. `timeZone` must be `Europe/Tirane` so the bucket boundary matches the day the user means; a UTC bucket silently splits the local evening across two days.

Per metric, from the one response: today's bucket (missing = 0), the previous day's bucket, and the mean over the seven calendar days ending on the previous day (sum then divide by 7, missing days as 0).

## The daily recap cache

`/root/.hermes/data/twenty-daily/activity.json`, one entry per local day:

```json
{"days": {"2026-09-24": {"signups": 4, "applications": 0, "newsletter_subs": 0, "purchases": 0}}}
```

A cron job reads this first and, when the day's key is present, renders from the cache with zero Twenty calls; only a missing key triggers the four `group_by` calls above, after which the job rewrites the file with the previous days kept. That check is also the idempotency guard (a manual fire cannot double-count). The job prompt that does this is kept beside the data at `/root/.hermes/data/twenty-daily/job-prompt.md` — edit that file and push it to the job with `hermes cron edit`, they drift otherwise.

## Adding a metric

1. Confirm the object has records that move per day (an empty or near-empty object earns no line).
2. Add one `group_by_<object>` call to the prompt with the same day-bucket arguments.
3. Add the key to the cache entry and one line to the message skeleton — same shape, one fact per line, no extra row format.
4. Re-render the message through a throwaway CLI session before the next fire.

Revenue is deliberately not a line yet: `purchases.amount` is a currency field, so `SUM` on it returns 0 and a revenue figure needs a separate `find_many_purchases` read summed by hand. If it is added, do that read explicitly rather than reporting a summed 0 as revenue.
