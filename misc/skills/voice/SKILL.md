---
name: voice
description: Humanize text by removing AI writing tells without changing the facts, build a reusable voice profile from real writing, or rewrite to match a supplied sample. Use for "humanize this", "make this sound less AI", "build my voice profile", or "make this sound like me".
license: MIT
metadata:
  version: "1.1.0"
---

# Voice

Read only the intent you need, then start with the supplied text or sources.

| User wants | Read |
| --- | --- |
| Humanize prose or remove AI writing tells | [Humanize](intents/humanize/README.md) |
| Build a reusable voice profile from real writing | [Build a profile](intents/profile/README.md) |
| Match a writing sample or an existing profile | [Apply a sample](intents/apply-sample/README.md) |

If asked to humanize and match a sample, read both intents. The sample wins on style; the source text wins on facts.
