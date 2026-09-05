---
name: ga4-track-server-event
description: Map a server-side analytics event to GA4 via the Measurement Protocol in the coverlttr SvelteKit project. Use when asked to add GA4 tracking for a server action, page load, signup, purchase, or any server-side interaction. Does not cover Umami or Meta — those have their own skills.
---

# Mapping a Server Event to GA4

GA4 server-side tracking uses the Measurement Protocol. Events are sent inside `trackServerEvent()`, which calls `sendGa4()` automatically. Your job is to map the `ServerAnalyticsEvent` name to the correct GA4 event name.

> **Before finishing, ask the user:** do you also want to add this event to **Umami** (`/umami-track-server-event`) and/or **Meta Conversions API** (`/meta-track-server-event`)?

## Relevant files

| File | Purpose |
|------|---------|
| `src/lib/server/analytics/context.ts` | `ServerAnalyticsEvent` union type — must include the event before mapping it |
| `src/lib/server/analytics/destinations/ga4.ts` | `GA4_EVENT` map + `sendGa4()` sender |

## Step 1 — Ensure the event exists in the union type

Check `src/lib/server/analytics/context.ts`:

```ts
export type ServerAnalyticsEvent = 'marketing_landing_view' | 'signup_completed' | 'purchase_completed';
```

If your event is not already in this union, add it now. Naming: `snake_case`, past tense — e.g. `cover_letter_generated`.

## Step 2 — Add the GA4 event name mapping

Open `src/lib/server/analytics/destinations/ga4.ts` and add your event to `GA4_EVENT`:

```ts
const GA4_EVENT: Record<ServerAnalyticsEvent, string> = {
  marketing_landing_view: 'page_view',
  signup_completed: 'sign_up',
  purchase_completed: 'purchase',
  your_new_event: 'your_ga4_event_name',   // add this line
};
```

### Choosing the right GA4 event name

Prefer [recommended GA4 event names](https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference/events) when one fits:

| Scenario | GA4 event name |
|----------|----------------|
| Page view | `page_view` |
| Sign up | `sign_up` |
| Purchase | `purchase` |
| Generate lead | `generate_lead` |
| Login | `login` |
| Search | `search` |
| Share | `share` |
| Tutorial begin | `tutorial_begin` |
| Tutorial complete | `tutorial_complete` |

For anything else, use a descriptive `snake_case` custom event name.

## What gets sent automatically

`sendGa4` maps context fields to GA4 params automatically — no extra work needed for these:

| Context field | GA4 param |
|---------------|-----------|
| `ctx.clientId` / `ctx.userId` | `client_id` |
| `ctx.userId` | `user_id` |
| `ctx.eventSourceUrl` | `page_location` |
| `ctx.campaign` | `campaign` |
| `ctx.variant` | `variant` |
| `ctx.tag` | `tag` |
| `ctx.value` | `value` |
| `ctx.currency` | `currency` |
| `ctx.orderId` | `transaction_id` |

## Current event map (reference)

```ts
// src/lib/server/analytics/destinations/ga4.ts
const GA4_EVENT: Record<ServerAnalyticsEvent, string> = {
  marketing_landing_view: 'page_view',
  signup_completed: 'sign_up',
  purchase_completed: 'purchase',
};
```

## Checklist

1. Event exists in `ServerAnalyticsEvent` union in `context.ts`.
2. Entry added to `GA4_EVENT` in `ga4.ts` with an appropriate GA4 event name.
3. TypeScript compiles — `Record<ServerAnalyticsEvent, string>` will error if any event is missing from the map.
4. Asked the user whether they also want Umami and Meta mappings.
