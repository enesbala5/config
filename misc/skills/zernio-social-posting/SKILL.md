---
name: zernio-social-posting
description: "Use when scheduling or publishing social posts via Zernio across one or more workspaces (e.g. X/LinkedIn on a paid key, Facebook/Instagram on a free key, personal X/Reddit on a personal key), including Coverlttr cadence and link-placement rules."
metadata:
  version: 1.0.0
---

# Zernio social posting

Use when scheduling or publishing via Zernio across **one or more workspaces**. Prefer the API over the dashboard once keys are stored. Works for Coverlttr brand surfaces and personal/community accounts.

## Secrets (never in skill, chat, or git)

- One API key **per Zernio workspace**, named as an env var (e.g. `ZERNIO_API_KEY`, `ZERNIO_API_KEY_B`, `ZERNIO_API_KEY_PERSONAL`).
- Collect via `secret-request` only — never paste `sk_…` into chat.
- Platform `box-secrets.json` often wipes empty. Sync into the durable file (Enes-approved):
  - **File:** `/home/box/.config/zernio/keys.env` (chmod 600)
  - **Loader:** `/home/box/bin/zernio-load-env` (`--status` / `--export`; always loads on `runpy.run_path`)
- Base URL: `https://zernio.com/api/v1`
- Auth: `Authorization: Bearer $<ENV_KEY_NAME>`

### Add a new workspace

1. Create an API key in that Zernio workspace (Settings → API Keys).
2. `secret-request` with a clear env name (e.g. `ZERNIO_API_KEY_PERSONAL`).
3. Append `NAME=sk_…` to `/home/box/.config/zernio/keys.env` (or ask Workflow Master / Promoter to sync without printing).
4. OAuth-connect the social accounts in that workspace (Reddit / new networks need **Enes’s explicit OK** first).
5. `GET /v1/accounts` with that key → add surfaces to the routing table (**IDs + labels only**, never keys).

## Routing map (hashmap)

Live ID table (no secrets): `/home/box/.config/zernio/routing.json`

Conceptual shape — `env_key_name` → list of surfaces:

```json
{
  "ZERNIO_API_KEY_PERSONAL": [
    { "platform": "twitter", "accountId": "…", "label": "Personal X" },
    { "platform": "reddit", "accountId": "…", "label": "Personal Reddit" }
  ],
  "ZERNIO_API_KEY": [
    { "platform": "twitter", "accountId": "…", "label": "Coverlttr X" },
    { "platform": "linkedin", "accountId": "…", "label": "Coverlttr LinkedIn" }
  ],
  "ZERNIO_API_KEY_B": [
    { "platform": "facebook", "accountId": "…", "label": "Coverlttr Facebook" },
    { "platform": "instagram", "accountId": "…", "label": "Coverlttr Instagram" }
  ]
}
```

Aliases: `ZERNIO_API_KEY_A` may appear as a synonym for paid Coverlttr; prefer `ZERNIO_API_KEY` as the canonical paid name.

Refresh IDs after reconnects:

```bash
eval "$(/home/box/bin/zernio-load-env --export)"
curl -s https://zernio.com/api/v1/accounts \
  -H "Authorization: Bearer $ZERNIO_API_KEY"
# repeat per workspace env name
```

## Inputs for one run

- `surfaces[]` — which labels/platforms from the routing map
- `content` — main body (platform-native; optional `customContent` per platform)
- `mediaItems[]` optional — public HTTPS URLs
- `mode` — `draft` | `schedule` (`scheduledFor` + `timezone`) | `publishNow`
- `firstComment` / thread extras when supported
- Brand / personal voice rules for that surface

## Steps

1. **Load keys** via `zernio-load-env`.
2. **Resolve surfaces** from `routing.json`. Group by `env_key_name` (one API call per workspace).
3. **Load copy** from Promoter / campaign docs — do not invent claims that violate guardrails.
4. **Apply link / tone rules** (below) per platform.
5. **Create post** per workspace group with `x-request-id` for idempotency.
6. **Confirm** `GET /v1/posts/{postId}`; record `platformPostUrl` when published.
7. **Report** to Promoter (cadence owner) / Head of Staff as needed — avoid duplicate-pinging Enes.

```bash
curl -s -X POST https://zernio.com/api/v1/posts \
  -H "Authorization: Bearer $ZERNIO_API_KEY" \
  -H "Content-Type: application/json" \
  -H "x-request-id: $(uuidgen)" \
  -d '{
    "content": "...",
    "scheduledFor": "2026-09-10T18:00:00",
    "timezone": "Europe/Tirane",
    "platforms": [
      {
        "platform": "facebook",
        "accountId": "ACCOUNT_ID",
        "platformSpecificData": { "firstComment": "https://…" }
      }
    ]
  }'
```

## Platform rules

### X / Twitter
- Prefer **no outbound URL in the main body** (Wave-1 / organic): link in first reply, thread-end, bio, or keyword/DM.
- Link-in-post only for explicit time-sensitive promo.
- No em dashes in Coverlttr X posts/replies (Enes rule).
- Prefer useful community replies over hard sell.

### LinkedIn / Facebook
- Prefer **no body URL**; put UTM’d landing in `platformSpecificData.firstComment` (or `firstComment`) with a soft “Link in the first comment.”
- Coverlttr LI/FB cadence owned by Promoter — ping before denser queues.

### Instagram
- Only when creatives exist; otherwise leave dark.
- Workspace B (`ZERNIO_API_KEY_B`).

### Reddit (posts + comments)
- Platform value: `reddit`. Use **personal** workspace key unless Enes explicitly green-lights a brand Reddit account.
- **Connecting Reddit or any new network requires Enes’s explicit OK** before OAuth.
- Early comments / posts: no link spam; lead with useful community value.
- Respect subreddit rules (flair, title format, self-promo limits, cooldown). Prefer organic engagement over hard sell.
- Personal vs brand: keep voice separate — personal Reddit ≠ Coverlttr Page tone.
- Prefer comments in relevant threads over cold link posts when building trust.

## Coverlttr brand guardrails

- Applicant is the hero; Coverlttr is the guide.
- CTA language: **Prepare** (not Generate as primary CTA).
- No hiring guarantees, no “ATS-proof,” no mass-apply celebration.
- Landing: `https://www.coverlttr.com/from-scratch` + UTMs when links are used.

## Cadence hooks

Routines call this skill by intent (not frozen curl):

- LI / FB sequences: Promoter copy + schedule via the matching workspace key.
- X shorts: Coverlttr or personal workspace as specified; link rules above.
- Reddit organic: Promoter routines; personal key; comments-first by default.
- Multi-workspace ship: one createPost call per env key group.

## Safety

- Never write `sk_…` into skills, memory facts, git, or chat.
- Idempotent creates: always send `x-request-id`.
- Confirm before `publishNow` unless a standing routine already approved that cadence.
- No fake/burner accounts — only Zernio-connected identities.
- No Reddit / new account connections without Enes OK.
