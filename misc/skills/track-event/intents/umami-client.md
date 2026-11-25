# Intent: client-side Umami (coverlttr Svelte)

Use only for browser interactions tracked by Umami. This intent does not cover server-side Umami, GA4, or Meta.

Umami client events use HTML data attributes; no JS import is needed:

```svelte
<Button
  onclick={handleCopy}
  data-umami-event="copied-referral-code"
  data-umami-event-type="referral"
>
  Copy referral code
</Button>
```

- Name events in descriptive, past-tense kebab-case (`copied-referral-code`, `navigated-to-developer-website`); omit filler words.
- Set `data-umami-event-type` to a sensible category. Add useful dimensions with `data-umami-event-<key>={value}`.
- Put attributes on the outermost interactive element (`<a>`, `<button>`, or a component rendering one), not a wrapper. The project's ShadCN `<Button>` forwards unknown attributes.
- Do not call `umami.track()` unless the event cannot be expressed declaratively (for example, programmatic navigation without a click).
- The shared `Analytics` service sets `data-distinct-id` from the `cl_aid` cookie on attach. Do not call `umami.identify()` with a different ID: server purchase events use `cl_aid` too, and mismatched IDs break Umami Attribution and Revenue linking.

Check: descriptive event name, suitable type, correct interactive element, and no unnecessary JS import.
