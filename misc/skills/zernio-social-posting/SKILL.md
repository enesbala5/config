---
name: zernio-social-posting
description: Existing entry point for Zernio delivery via social, including Coverlttr and personal account guardrails.
---

# Zernio social posting

Use the `social` skill for delivery. Its on-demand `zernio-mcp` command, setup and account selection are documented in `<config>/misc/modules/marketing/providers/zernio/README.md`. Do not export workspace keys or maintain a routing table. Group approved targets by workspace; create and confirm one post per group. Capture published platform URLs when available. Obtain explicit approval for new connections and for immediate publishing outside an approved cadence.

## Existing Coverlttr and personal routines

- Use approved campaign copy. The applicant is the hero; Coverlttr is the guide. Prefer **Prepare**, not Generate. No hiring guarantees, ATS-proof claims or mass-apply promotion. Link to `https://www.coverlttr.com/from-scratch` with UTMs where appropriate.
- X: no em dashes on Coverlttr posts or replies. Prefer useful replies; put organic links in first reply, thread end or bio unless an explicit time-sensitive promo calls for a body link.
- LinkedIn / Facebook: prefer the UTM link in `platformSpecificData.firstComment`. Coordinate denser queues with Promoter.
- Instagram: only schedule when creatives exist.
- Reddit: use personal identity unless the owner explicitly approves brand use. Respect subreddit self-promotion, flair, title and cooldown rules; prefer helpful comments, not link spam. No burners.
- Report outcomes to the cadence owner without duplicate notifications.
