---
name: openhands
description: "Delegate coding to the OpenHands agent server on byok-agent (features, refactors, PRs)."
version: 1.2.0
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

## Attaching files (documents and images)

Don't paste a file's contents into `--prompt` by hand. Write it to a file and
pass it with `--file` (repeatable, any file type); the script handles delivery.
`--md` is kept as an alias.

```
terminal(command="oh-start.sh --file /var/lib/hermes/scratch/task.md")
```

Works with or without `--prompt`:

```
terminal(command="oh-start.sh --prompt 'Implement this plan' --file /var/lib/hermes/scratch/plan.md --repo https://github.com/org/repo.git")
```

Two delivery paths, chosen automatically by file type:

- **Text files** (Markdown, code, logs, ...):
  - **Default (convert):** read and inlined into the prompt as an
    `# Attached document: <name>` section.
  - **`--file-upload` (blob):** uploaded into the agent workspace via
    `POST /api/file/upload` and referenced by path, so a large file does not
    bloat the prompt. A failed upload falls back to inlining.

  ```
  terminal(command="oh-start.sh --prompt 'Follow the spec' --file /var/lib/hermes/scratch/spec.md --file-upload")
  ```

- **Images** (`png`, `jpg`/`jpeg`, `gif`, `webp`, `bmp`, `tif`/`tiff`): embedded
  directly in the initial message as base64 image content, so a multimodal model
  can see them. Multiple `--file` images become multiple content parts, in the
  order given.

  ```
  terminal(command="oh-start.sh --prompt 'Compare these screenshots' --file /var/lib/hermes/scratch/before.png --file /var/lib/hermes/scratch/after.png --model openai/gpt-4o")
  ```

  **Images require a vision-capable model.** The default `deepseek/deepseek-chat`
  is text-only, and the agent server silently drops image content for such a
  model. Pass a multimodal `--model` (and its key) or the images do nothing. The
  script prints a note to stderr whenever it embeds images.

The Agent Server message format only supports `text` and `image` content, so
`--file-upload` uses the workspace file API rather than a message attachment;
images use the `image` content type.

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
- `POST .../api/file/upload?path=<absolute>` (multipart `file`) for text files
  attached with `--file-upload`
- image files become `{type: "image", image_urls: ["data:..."]}` parts in
  `initial_message.content`, alongside the `{type: "text", ...}` part

If you ever need to call the API directly (e.g. to list conversations), reuse
the same header and base URL rather than re-deriving auth.
