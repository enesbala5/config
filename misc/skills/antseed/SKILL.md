---
name: antseed
description: Route Antseed tasks to the preserved buyer setup, Hermes integration, System One decisions, or SQLite migration procedure. Use when joining Antseed as a buyer, connecting Hermes, evaluating typed decisions, or adding Antseed node migrations.
---

# Antseed

Choose exactly one intent and follow its full procedure. Each intent file contains the original complete procedure, including setup steps, commands, endpoint details, and safety rules.

| User goal | Intent file |
| --- | --- |
| Set up/fund a buyer or connect a tool to the buyer proxy | [`intents/join-buyer.md`](intents/join-buyer.md) |
| Connect Hermes Agent locally or remotely | [`intents/hermes-antseed.md`](intents/hermes-antseed.md) |
| Ask System One/TypeSafe typed decision questions | [`intents/antseed-decisions.md`](intents/antseed-decisions.md) |
| Add a SQLite migration to the Antseed node package | [`intents/add-migration.md`](intents/add-migration.md) |

## Portability gate

This skill and its intent files must remain usable across agent harnesses. Use ordinary filesystem, shell, and HTTP operations; any harness-specific integration is optional and must have a complete portable alternative. Keep endpoints and authentication variable names documented, never embed secrets, avoid machine-specific absolute paths, and verify all procedures with documented commands. Intent files are self-contained preserved procedures; do not omit their setup, funding, proxy URL, or migration command details when editing them.
