---
name: openhands
description: "Delegate coding to the OpenHands agent server on byok-agent (features, refactors, PRs)."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [Coding-Agent, OpenHands, Autonomous, Refactoring, Code-Review]
    related_skills: [codex, opencode, claude-code, hermes-agent]
---

# OpenHands Agent Server

Delegate coding tasks to the OpenHands agent server running in the `byok-agent`
Incus VM. Coding runs there, not on this host.

## When to use

- The user asks you to clone a repo and make a change, fix, refactor, or review
- The task is multi-file or long-running enough that a dedicated coding agent
  should own it

Do **not** run coding agents locally on this host, and do not wrap or translate
OpenHands events. Start the conversation, hand the user the URL, and stop.

## Prerequisites

- `oh-start.sh` is installed at `/usr/local/bin/oh-start.sh`
- The agent server is reachable at `http://byok-agent.incus:8000`
- `/etc/hermes-env` carries `OH_SESSION_API_KEY` (the script sources it) and a
  usable LLM key (`DEEPSEEK_API_KEY`); `oh-start.sh` reads them itself

## Start a conversation

Use the `terminal` tool:

```
terminal(command="oh-start.sh --prompt 'Add a retry to the HTTP client and update tests'")
```

With a repo (the agent host clones it; this host does not):

```
terminal(command="oh-start.sh --prompt 'Fix the flaky auth test' --repo https://github.com/org/repo.git")
```

Optional `--model <id>` overrides the default model.

## What it returns

```
conversation_id=<id>
https://agent.enesbala.com/conversations/<id>
```

Send the user the URL. The task runs asynchronously on `byok-agent`; you do not
wait for it or poll it. Completion notices arrive over the shared Telegram
channel prefixed `[byok-agent]`.

## Under the hood

`oh-start.sh` is a thin REST client:

- `POST http://byok-agent.incus:8000/api/conversations` with
  `X-Session-API-Key: $OH_SESSION_API_KEY`
- `POST .../api/conversations/<id>/run`

If you ever need to call the API directly (e.g. to list conversations), reuse
the same header and base URL rather than re-deriving auth.
