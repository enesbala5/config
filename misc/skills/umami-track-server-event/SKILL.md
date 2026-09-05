---
name: umami-track-server-event
description: Add a new server-side Umami analytics event in the coverlttr SvelteKit project. Use when asked to track a server action, page load, form submission, auth callback, or any server-side interaction specifically for Umami. Does not cover GA4 or Meta — those have their own skills.
---

# Tracking Server-Side Umami Events

Server events flow through a shared pipeline. The same `trackServerEvent` call sends to Umami, GA4, and Meta simultaneously — so adding an event here will also appear in the other destinations once mapped.

> **Before finishing, ask the user:** do you also want to add this event to **GA4** (`/ga4-track-server-event`) and/or **Meta Conversions API** (`/meta-track-server-event`)?

## Relevant files

| File | Purpose |
|------|---------|
| `src/lib/server/analytics/context.ts` | `ServerAnalyticsEvent` union type + `TrackServerEventPayload` type |
| `src/lib/server/analytics/track.ts` | `trackServerEvent()` — fire-and-forget, sends to all destinations |
| `src/lib/server/analytics/index.ts` | Public re-exports — always import from here |
| `src/lib/server/analytics/destinations/umami.ts` | Umami-specific sender |

## Step 1 — Add the event name to the union type

Open `src/lib/server/analytics/context.ts` and extend `ServerAnalyticsEvent`:

```ts
// before
export type ServerAnalyticsEvent = 'marketing_landing_view' | 'signup_completed' | 'purchase_completed';

// after
export type ServerAnalyticsEvent = 'marketing_landing_view' | 'signup_completed' | 'purchase_completed' | 'your_new_event';
```

Naming convention: `snake_case`, past tense where possible — e.g. `cover_letter_generated`, `referral_signup_completed`.

> Note: `ServerAnalyticsEvent` is used as the key type for `Record<ServerAnalyticsEvent, string>` maps in `ga4.ts` and `meta.ts`. Adding a new value here will cause **TypeScript errors** in those files until they are updated too — that's intentional and acts as a reminder.

## Step 2 — Add the Umami event name mapping

Open `src/lib/server/analytics/destinations/umami.ts`. The `name` field sent to Umami is the raw `ServerAnalyticsEvent` string (no mapping needed — it is sent as-is). No change required in this file.

## Step 3 — Call trackServerEvent at the right site

Import from `$lib/server/analytics` and call it — **do not await**:

```ts
import { trackServerEvent } from '$lib/server/analytics';

// In a load() function (+page.server.ts):
export const load: PageServerLoad = async ({ cookies, url, request, getClientAddress, locals }) => {
  trackServerEvent('your_new_event', {
    cookies,
    url,
    request,
    getClientAddress,
    userId: locals.user?.id,
    eventSourceUrl: url.href,
  });
  // ...
};

// In a form action or +server.ts route:
trackServerEvent('your_new_event', {
  cookies,
  url,
  request,
  getClientAddress,
  userId: user.id,
  email: user.email,
});
```

## TrackServerEventPayload fields

All fields are optional — pass what is available in the current handler.

| Field | Type | Description |
|-------|------|-------------|
| `cookies` | `Cookies` | SvelteKit cookies — reads/sets client ID, fbp, fbc, campaign attribution |
| `url` | `URL` | Current request URL |
| `request` | `Request` | Raw request — used for IP, user-agent, bot detection |
| `getClientAddress` | `() => string` | SvelteKit fn for real client IP |
| `userId` | `string` | Internal user ID |
| `email` | `string` | User email |
| `eventSourceUrl` | `string` | Override the page URL sent to Umami |
| `campaign` | `string` | UTM campaign override |
| `variant` | `string` | A/B variant tag |
| `tag` | `string` | Arbitrary tag string |
| `value` | `number` | Monetary value |
| `currency` | `string` | ISO 4217 currency code e.g. `"USD"` |
| `orderId` | `string` | Deduplication ID |

## Real examples from the codebase

```ts
// Landing page view
trackServerEvent('marketing_landing_view', {
  cookies, url, request, getClientAddress,
  userId: locals.user?.id,
  eventSourceUrl: url.href,
});

// After signup in auth callback
trackServerEvent('signup_completed', {
  cookies, url, request, getClientAddress,
  userId: user.id,
  email: user.email,
});
```

## Checklist

1. New event name added to `ServerAnalyticsEvent` union in `context.ts`.
2. TypeScript compiles — fix any resulting errors in `ga4.ts` / `meta.ts` by adding placeholder mappings or by implementing those skills too.
3. `trackServerEvent` called (not awaited) with at minimum `cookies`, `url`, `request`, `getClientAddress`.
4. Asked the user whether they also want GA4 and Meta mappings.
