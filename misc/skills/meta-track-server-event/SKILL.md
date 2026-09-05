---
name: meta-track-server-event
description: Map a server-side analytics event to Meta Conversions API in the coverlttr SvelteKit project. Use when asked to add Meta/Facebook pixel server-side tracking for a signup, purchase, page view, or any server-side interaction. Does not cover Umami or GA4 — those have their own skills.
---

# Mapping a Server Event to Meta Conversions API

Meta server-side tracking uses the Conversions API (CAPI). Events are sent inside `trackServerEvent()`, which calls `sendMeta()` automatically. Your job is to map the `ServerAnalyticsEvent` name to the correct Meta standard or custom event name.

> **Before finishing, ask the user:** do you also want to add this event to **Umami** (`/umami-track-server-event`) and/or **GA4** (`/ga4-track-server-event`)?

## Relevant files

| File | Purpose |
|------|---------|
| `src/lib/server/analytics/context.ts` | `ServerAnalyticsEvent` union type — must include the event before mapping it |
| `src/lib/server/analytics/destinations/meta.ts` | `META_EVENT` map + `sendMeta()` sender |
| `src/lib/server/analytics/hash.ts` | `hashEmail()` — used for PII hashing (already handled internally) |

## Step 1 — Ensure the event exists in the union type

Check `src/lib/server/analytics/context.ts`:

```ts
export type ServerAnalyticsEvent = 'marketing_landing_view' | 'signup_completed' | 'purchase_completed';
```

If your event is not already in this union, add it now. Naming: `snake_case`, past tense — e.g. `cover_letter_generated`.

## Step 2 — Add the Meta event name mapping

Open `src/lib/server/analytics/destinations/meta.ts` and add your event to `META_EVENT`:

```ts
const META_EVENT: Record<ServerAnalyticsEvent, string> = {
  marketing_landing_view: 'PageView',
  signup_completed: 'CompleteRegistration',
  purchase_completed: 'Purchase',
  your_new_event: 'YourMetaEventName',   // add this line
};
```

### Choosing the right Meta event name

Prefer [Meta standard events](https://developers.facebook.com/docs/meta-pixel/reference#standard-events) when one fits — they unlock optimisation signals in Ads Manager:

| Scenario | Meta standard event |
|----------|---------------------|
| Page view | `PageView` |
| Sign up / registration | `CompleteRegistration` |
| Purchase | `Purchase` |
| Lead captured | `Lead` |
| Add to cart | `AddToCart` |
| Initiate checkout | `InitiateCheckout` |
| View content / feature | `ViewContent` |
| Search | `Search` |
| Subscribe | `Subscribe` |
| Start trial | `StartTrial` |

For anything that doesn't fit a standard event, use a descriptive `PascalCase` or `snake_case` custom event name string.

## What gets sent automatically

`sendMeta` maps context fields to CAPI payload fields automatically — no extra work needed:

| Context field | CAPI field |
|---------------|-----------|
| `ctx.email` | `user_data.em` (SHA-256 hashed) |
| `ctx.ip` | `user_data.client_ip_address` |
| `ctx.userAgent` | `user_data.client_user_agent` |
| `ctx.fbp` | `user_data.fbp` |
| `ctx.fbc` | `user_data.fbc` |
| `ctx.userId` | `user_data.external_id` |
| `ctx.eventId` | `event_id` (for deduplication with browser pixel) |
| `ctx.eventSourceUrl` | `event_source_url` |
| `ctx.campaign` | `custom_data.campaign` |
| `ctx.variant` | `custom_data.variant` |
| `ctx.tag` | `custom_data.tag` |
| `ctx.value` | `custom_data.value` |
| `ctx.currency` | `custom_data.currency` |
| `ctx.orderId` | `custom_data.order_id` |

For `Purchase` events, `value` and `currency` are required by Meta — make sure the `trackServerEvent` call at the usage site passes them.

## Current event map (reference)

```ts
// src/lib/server/analytics/destinations/meta.ts
const META_EVENT: Record<ServerAnalyticsEvent, string> = {
  marketing_landing_view: 'PageView',
  signup_completed: 'CompleteRegistration',
  purchase_completed: 'Purchase',
};
```

## Checklist

1. Event exists in `ServerAnalyticsEvent` union in `context.ts`.
2. Entry added to `META_EVENT` in `meta.ts` with an appropriate Meta event name.
3. TypeScript compiles — `Record<ServerAnalyticsEvent, string>` will error if any event is missing from the map.
4. For purchase/revenue events: confirm `value` and `currency` are passed at the call site.
5. Asked the user whether they also want Umami and GA4 mappings.
