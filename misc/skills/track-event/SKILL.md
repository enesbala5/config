---
name: track-event
description: Add or map analytics events in coverlttr across client-side Umami and server-side Umami, GA4, or Meta Conversions API. Use when asked to track an interaction or add an analytics event; choose the matching provider and client/server intent.
---

# Track event

Choose exactly one intent based on provider and execution context, then follow that file:

- Client-side Umami in a Svelte component: [`intents/umami-client.md`](intents/umami-client.md)
- Server-side Umami in coverlttr's SvelteKit pipeline: [`intents/umami-server.md`](intents/umami-server.md)
- Server-side GA4 mapping: [`intents/ga4-server.md`](intents/ga4-server.md)
- Server-side Meta Conversions API mapping: [`intents/meta-server.md`](intents/meta-server.md)

Ask if provider or client/server context is unclear. These intents are intentionally separate. An intent's explicit “does not cover” boundary is a routing rule: do not implement other providers or contexts unless requested. The server destinations share `trackServerEvent()`, but adding one mapping does not authorize adding the other provider mappings. When the shared event union causes type errors in other `Record` maps, use deliberate placeholders or ask before expanding scope.
