---
name: umami-track-client-event
description: Add Umami analytics event tracking to client-side Svelte components in the coverlttr project. Use when asked to track a button click, link navigation, or any user interaction with data-umami-event attributes.
---

# Tracking Client-Side Umami Events

Umami client-side tracking is done through HTML data attributes — no JavaScript import needed. Add these attributes directly to the element that triggers the event.

## Required attribute

```svelte
data-umami-event="event-name-here"
```

## Optional supplementary attributes

```svelte
data-umami-event-type="category"        <!-- groups events, e.g. "referral", "navigation", "engagement" -->
data-umami-event-<key>={dynamicValue}   <!-- arbitrary extra dimensions, e.g. data-umami-event-website={url} -->
```

## Naming convention

- Kebab-case, past tense, verb-noun: `copied-referral-code`, `shared-referral-invite`, `navigated-to-developer-website`
- Omit articles and filler words
- Be specific enough to be unambiguous in the Umami dashboard

## Example — real usage in the project

```svelte
<!-- Footer link -->
<a
  href={developer.website}
  data-umami-event="navigated-to-developer-website"
  data-umami-event-type="navigation"
  data-umami-event-website={developer.website}
>...</a>

<!-- Button (ShadCN Button component also forwards data attributes) -->
<Button
  onclick={handleCopy}
  data-umami-event="copied-referral-code"
  data-umami-event-type="referral"
>
  Copy referral code
</Button>

<Button
  onclick={handleShare}
  data-umami-event="shared-referral-invite"
  data-umami-event-type="referral"
>
  Share
</Button>
```

## Placement rules

- Put the attributes on the **outermost interactive element** (`<a>`, `<button>`, or a component that renders one).
- Do **not** add them to non-interactive wrappers like `<div>` or `<span>`.
- The ShadCN `<Button>` component forwards unknown props/attributes, so data attributes work directly on it.
- Do **not** call `umami.track()` manually from JS unless the trigger cannot be expressed as a declarative attribute (e.g. programmatic navigation without a click).

## Checklist before finishing

1. Event name is kebab-case past-tense and descriptive.
2. `data-umami-event-type` is set to a sensible category.
3. The attribute is on the element the user actually interacts with.
4. No JS imports added — attributes only.
