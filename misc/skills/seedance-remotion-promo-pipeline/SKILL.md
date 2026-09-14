---
name: Seedance + Remotion promo pipeline
description: >-
  Use this when building or running a BYOK promo-video workflow: generate clips
  with Seedance 2.5, compose titles/CTAs in Remotion, and export MP4 without a
  subscription video SaaS.
---
# Seedance + Remotion promo pipeline

Reusable BYOK video workflow: generate raw clips with ByteDance Seedance 2.5, compose the branded promo in Remotion, export MP4. Prefer provider keys you control over all-in-one SaaS editors.

## Roles in the pipeline

| Stage | Tool | Owns |
| --- | --- | --- |
| Brief + script | Human / scripting agent | Hook, beats, CTA, aspect ratio, length |
| Shot list | Same | Per-shot prompt, refs, duration, audio on/off |
| Generate | Seedance 2.5 API (BYOK) | Raw B-roll / scene clips |
| Compose | Remotion | Titles, captions, logo, cuts, end card |
| Export | `npx remotion render` or `renderMedia` | Final MP4 (and optional stills) |
| Review | Human | Pick winners, re-gen weak shots only |

## Principles

1. **BYOK first** — Call Seedance through a path that uses your ByteDance/Volcano (or gateway pass-through) key. Avoid locked subscription editors for generation.
2. **Draft cheap, finish expensive** — Iterate at 480p; lock structure in Remotion; re-generate only failed shots at 720p+.
3. **Code owns the brand layer** — Logo, type, colors, CTA live in Remotion props, not baked into every Seedance prompt.
4. **One shot = one file** — Never ask Seedance to do titles + product demo + end card in one prompt. Generate scenes; compose the edit.
5. **Refs beat adjectives** — Product stills, character refs, motion refs, and audio refs beat long style paragraphs.

## Stage 0 — Brief (inputs)

Collect before any API call:

- **Goal**: awareness / demo / testimonial / launch
- **Platform**: 9:16 (Reels/TikTok/Shorts), 1:1, or 16:9
- **Length**: target seconds (e.g. 15 / 30 / 45)
- **Hook** (first 2–3s), **beats**, **CTA**
- **Brand kit**: logo path, hex colors, font, product stills, voice/tone notes
- **Must-show**: product UI, name, URL, offer

Output artifact: `brief.md` + `shots.json` (see schema below).

## Stage 1 — Shot list

Break the script into Seedance-sized shots (prefer 4–12s each; Seedance 2.5 supports up to ~30s native).

`shots.json` schema:

```json
{
  "project": "promo-name",
  "aspect": "9:16",
  "fps": 30,
  "shots": [
    {
      "id": "hook",
      "durationSec": 5,
      "mode": "text-to-video",
      "prompt": "…",
      "generateAudio": false,
      "resolutionDraft": "480p",
      "resolutionFinal": "720p",
      "refs": {
        "images": ["brand/product.png"],
        "videos": [],
        "audios": []
      },
      "notes": "Silent B-roll; captions come from Remotion"
    }
  ]
}
```

Modes:

- `text-to-video` — prompt only
- `image-to-video` — first/last frame
- `reference-guided` — images/videos/audios cited in the prompt (`[Image1]`, `[Video1]`, …)
- `edit` / `extend` — mutate or continue an existing clip

Prompt rules:

- One camera idea + one subject action per shot
- Cite refs explicitly in the prompt text
- Prefer `generateAudio: false` for promo B-roll (music/VO in Remotion) unless the shot is the audio moment
- Write multi-shot narrative as separate `shots[]` entries, not one mega-prompt

## Stage 2 — Seedance generate (BYOK)

### Access pattern

1. Obtain a ByteDance / Volcano Engine key (or use a gateway with **BYOK pass-through** so you pay the provider, not platform markup).
2. Pick one callable surface and stick to it for the project (model id like `bytedance/seedance-2.5`).
3. Store the key in env (`SEEDANCE_API_KEY` or gateway key + provider attachment). Never commit keys.

### Generate loop

For each shot in `shots.json`:

1. Build the request: model, prompt, duration, aspect/resolution, refs, `generate_audio`
2. Submit async job → poll until ready
3. Save to `raw/<shot-id>/draft.mp4` (480p)
4. Log cost, seed, request id in `raw/<shot-id>/meta.json`
5. Review: **keep / regen / rewrite prompt**

Only after the edit is locked in Remotion, re-run keepers at `resolutionFinal` into `raw/<shot-id>/final.mp4`.

### Cost hygiene

- Cap concurrent jobs
- Prefer shorter draft durations while iterating prompts
- Re-gen one shot, not the whole film
- Keep a `spend.md` running total per project

## Stage 3 — Remotion compose

### Project shape

```
promo/
  package.json
  src/
    Root.tsx
    compositions/Promo.tsx
    components/TitleCard.tsx
    components/Captions.tsx
    components/EndCard.tsx
    lib/timings.ts
  public/
    logo.png
    raw/
  props/
    episode.json
```

### Composition responsibilities

Remotion owns: intro sting / logo, lower-thirds and captions, cuts between Seedance clips, brand colors/type, end card, optional VO or music bed.

Embed Seedance outputs with `@remotion/media` `Video` + `staticFile()`. Parametrize via `inputProps` / `episode.json` so one composition ships many promos.

### Preview

```bash
npx remotion studio
```

Lock timing before any final Seedance upscale.

## Stage 4 — Export

```bash
npx remotion render Promo out/promo.mp4 --codec=h264
```

Programmatic: `bundle` → `selectComposition` → `renderMedia` with the same `inputProps`. Also export a still for thumbnails.

## Stage 5 — Review checklist

- [ ] Hook readable in first 2s without sound
- [ ] Product / brand consistent with refs
- [ ] Captions accurate; CTA clear in last 3s
- [ ] No subscription watermark; commercial-safe assets
- [ ] Length fits platform
- [ ] Weak shots listed for re-gen only

## Folder convention

```
projects/<slug>/
  brief.md
  shots.json
  spend.md
  raw/<shot-id>/{draft,final}.mp4
  remotion/
  out/<slug>-<aspect>.mp4
```

## Anti-patterns

- Generating full branded ads inside Seedance
- Paying a SaaS wrapper when BYOK pass-through is available
- Final-res on every prompt experiment
- One 30s “do everything” prompt
- Hardcoding copy in React instead of props

## Handoffs

- Scripting agent → `brief.md` + shot prompts
- This pipeline → generate + compose
- Human → keep/regen and publish
