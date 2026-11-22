# Intent: server-side Meta Conversions API (coverlttr SvelteKit)

Use to map a server-side event to Meta CAPI in coverlttr. This intent does not cover Umami or GA4 mappings.

## Files

- `src/lib/server/analytics/context.ts`: `ServerAnalyticsEvent` union; the event must be present before mapping it.
- `src/lib/server/analytics/destinations/meta.ts`: `META_EVENT` map and sender.
- `src/lib/server/analytics/hash.ts`: `hashEmail()`; PII hashing is handled internally.

Ensure the event is in the union, using `snake_case`, preferably past tense (for example `cover_letter_generated`). Add it to `META_EVENT`:

```ts
const META_EVENT: Record<ServerAnalyticsEvent, string> = {
  // existing entries
  your_new_event: 'YourMetaEventName',
};
```

Prefer a [Meta standard event](https://developers.facebook.com/docs/meta-pixel/reference#standard-events) when appropriate: `PageView`, `CompleteRegistration`, `Purchase`, `Lead`, `AddToCart`, `InitiateCheckout`, `ViewContent`, `Search`, `Subscribe`, or `StartTrial`. Otherwise use a descriptive `PascalCase` or `snake_case` custom name. The shared `trackServerEvent()` pipeline calls `sendMeta()` automatically.

Context mapping is automatic: email is SHA-256 hashed; IP, user-agent, fbp/fbc, external ID, event ID, source URL, campaign, variant, tag, value, currency, and order ID map to CAPI fields. For `Purchase`, ensure the call site passes both `value` and `currency`.

Verify union membership, mapping presence, TypeScript compilation, and purchase value/currency where applicable. `Record<ServerAnalyticsEvent, string>` requires every event in the map. Do not add Umami or GA4 mappings under this intent; resolve shared type errors with deliberate placeholders or ask before expanding scope.
