# Intent: server-side GA4 (coverlttr SvelteKit)

Use to map a server-side event to GA4 Measurement Protocol in coverlttr. This intent does not cover Umami or Meta mappings.

## Files

- `src/lib/server/analytics/context.ts`: `ServerAnalyticsEvent` union; the event must be present before mapping it.
- `src/lib/server/analytics/destinations/ga4.ts`: `GA4_EVENT` map and sender.

Ensure the event is in the union, using `snake_case`, preferably past tense (for example `cover_letter_generated`). Add it to `GA4_EVENT`:

```ts
const GA4_EVENT: Record<ServerAnalyticsEvent, string> = {
  // existing entries
  your_new_event: 'your_ga4_event_name',
};
```

Prefer a [recommended GA4 event name](https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference/events) when appropriate: `page_view`, `sign_up`, `purchase`, `generate_lead`, `login`, `search`, `share`, `tutorial_begin`, or `tutorial_complete`. Otherwise use a descriptive `snake_case` custom name. The shared `trackServerEvent()` pipeline calls `sendGa4()` automatically.

Context mapping is automatic: client/user IDs, `eventSourceUrl` to `page_location`, campaign, variant, tag, value, currency, and order ID to `transaction_id`.

Verify union membership, mapping presence, and TypeScript compilation. `Record<ServerAnalyticsEvent, string>` requires every event in the map. Do not add Umami or Meta mappings under this intent; resolve shared type errors with deliberate placeholders or ask before expanding scope.
