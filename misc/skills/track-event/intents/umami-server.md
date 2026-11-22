# Intent: server-side Umami (coverlttr SvelteKit)

Use for a server action, page load, form submission, auth callback, or other server-side interaction specifically requiring Umami. This intent does not cover GA4 or Meta mapping work, even though the shared sender dispatches to those destinations.

## Files

- `src/lib/server/analytics/context.ts`: `ServerAnalyticsEvent` union and `TrackServerEventPayload`.
- `src/lib/server/analytics/track.ts`: shared `trackServerEvent()` pipeline.
- `src/lib/server/analytics/index.ts`: public re-exports; import from here.
- `src/lib/server/analytics/destinations/umami.ts`: Umami sender.

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

Call sites include `+page.server.ts` loads, form actions, `+server.ts` routes, and auth callbacks. Payload fields are optional: `cookies` (client ID, fbp/fbc, attribution), `url`, `request` (IP/user-agent/bot context), `getClientAddress`, `userId`, `email`, `eventSourceUrl`, `campaign`, `variant`, `tag`, `value`, `currency`, and `orderId`. Supply cookies, URL, request, and `getClientAddress` where available.

Adding a union value may cause TypeScript errors in GA4 and Meta `Record<ServerAnalyticsEvent, string>` maps. Preserve this intent's boundary: add deliberate placeholder entries if appropriate, or ask before implementing those provider mappings.

Verify union membership, a non-awaited call, and relevant project typecheck/tests. Report any placeholders and unimplemented destinations.
