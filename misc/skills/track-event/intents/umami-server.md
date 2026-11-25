# Intent: server-side Umami (coverlttr SvelteKit)

Use for a server action, page load, form submission, auth callback, or other server-side interaction specifically requiring Umami. This intent does not cover GA4 or Meta mapping work, even though the shared sender dispatches to those destinations.

## Files

- `src/lib/server/analytics/context.ts`: `ServerAnalyticsEvent` union and `TrackServerEventPayload`.
- `src/lib/server/analytics/track.ts`: shared `trackServerEvent()` pipeline.
- `src/lib/server/analytics/index.ts`: public re-exports; import from here.
- `src/lib/server/analytics/destinations/umami.ts`: Umami sender.
- `src/lib/server/analytics/purchasePlan.ts`: resolves `plan` / `period` for paid Polar orders (via `resolvePolarPlan`, with the user's stored plan as fallback).

Add the event to `ServerAnalyticsEvent` if needed. Use `snake_case`, past tense where possible (for example `cover_letter_generated`, `referral_signup_completed`). Umami sends the raw internal event string; no mapping change is required in `destinations/umami.ts`.

Call `trackServerEvent()` from `$lib/server/analytics` at the appropriate handler and **do not await it**:

```ts
import { trackServerEvent } from '$lib/server/analytics';

trackServerEvent('your_new_event', {
  cookies, url, request, getClientAddress,
  userId: locals.user?.id,
  eventSourceUrl: url.href,
});
```

Call sites include `+page.server.ts` loads, form actions, `+server.ts` routes, and auth callbacks. Payload fields are optional: `cookies` (client ID, fbp/fbc, attribution), `url`, `request` (IP/user-agent/bot context), `getClientAddress`, `userId`, `email`, `eventSourceUrl`, `campaign`, `variant`, `tag`, `value`, `currency`, `orderId`, `plan`, and `period`. `plan` / `period` are lowercase purchase properties (for example `pro` / `yearly`); `trackPaidPolarOrder()` fills them from the order product, so hand-written purchase events should supply them too. Supply cookies, URL, request, and `getClientAddress` where available.

Umami specifics for purchase events:

- `destinations/umami.ts` mirrors `value` as `revenue` (plus `currency`). The Umami Revenue insight aggregates only a property literally named `revenue`; do not drop the alias.
- The server event sets `id` to `cl_aid` (the distinct ID). The client script reads the same cookie and sets `data-distinct-id`, so pageviews and server events share a visitor — required for the Attribution insight (first-click / last-click). Keep both sides on the same ID (`src/lib/services/analytics/cookieKeys.ts`); if you change the cookie name or make it httpOnly again, attribution breaks.

Adding a union value may cause TypeScript errors in GA4 and Meta `Record<ServerAnalyticsEvent, string>` maps. Preserve this intent's boundary: add deliberate placeholder entries if appropriate, or ask before implementing those provider mappings.

Verify union membership, a non-awaited call, and relevant project typecheck/tests. Report any placeholders and unimplemented destinations.
