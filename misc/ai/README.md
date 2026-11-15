# Local inference (home-server)

`home-server` runs one GGUF through `llama-server` (Vulkan, RX 570) and exposes
a plain OpenAI-compatible API. Any harness that can talk `chat/completions` can
use it: pi, opencode, Hermes, OpenHands, a throwaway `curl`.

This file is the harness-neutral contract. Nix-managed clients read their
values from `nix/nixos/modules/home/programs/local-ai` instead of this page, so
the two cannot drift.

## Endpoint

| Field | Value |
| --- | --- |
| Base URL (tailnet) | `http://home-server:8080/v1` |
| Base URL (Incus guest) | `http://10.0.100.1:8080/v1` |
| Model id | `qwen` (Qwen3-4B Q4_K_M) |
| API key | none — send any non-empty placeholder |
| Context | 8192 tokens, one slot |
| Tools | function calling works (`tools` + `tool_choice`) |
| Thinking | Qwen3 hybrid; off by default via `chat_template_kwargs` |

Reachability: `home-server` resolves over Tailscale MagicDNS
(`100.88.203.12`), and the port is open only on `tailscale0`. The tailnet must
be up on the client. LAN clients need `homeServer.ai.openFirewall = true` on
the server first. Incus guests reach the host at `10.0.100.1` because
`incusbr0` is a trusted interface — no firewall change needed.

## Rules of thumb

- **Turn thinking off for agent loops.** Qwen3 thinks by default and spends
  most of an 8K window on `reasoning_content` before answering. Send
  `"chat_template_kwargs": {"enable_thinking": false}`.
- **One request at a time.** The server runs `--parallel 1`; concurrent
  requests queue rather than sharing context.
- **8K total, prompt included.** System prompt plus tool schemas already cost
  a few thousand tokens. Expect agents to compact or truncate early; this is
  not a window for whole-file refactors.
- **Capability.** Good at short, well-scoped edits and explanations. Do not
  expect multi-step refactors or long tool chains to hold together.

## Verify

```bash
curl -s http://home-server:8080/health                     # {"status":"ok"}
curl -s http://home-server:8080/v1/models                  # id: "qwen"
curl -s http://home-server:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen","messages":[{"role":"user","content":"Say OK."}],
       "max_tokens":32,"chat_template_kwargs":{"enable_thinking":false}}'
```

## Wiring a harness

**pi** — generated, nothing to do. `~/.pi/agent/models.json` is written by
`nix/nixos/hosts/framework-13/home/default.nix` from `modules.home.localAi`,
with provider id `home-server` and model id `qwen`. Select it in `/model`, or
start with `pi --model home-server/qwen`. Use `/thinking off`.

**opencode** — `nix/nixos/modules/home/programs/opencode/providers.nix` carries
a commented-out `provider.home-server` block. Uncomment it, rebuild, then
`opencode models` should list `home-server/qwen`. The block is off because
opencode resolves custom providers through `npm`, which installs
`@ai-sdk/openai-compatible` into `~/.cache/opencode` on first use.

**Hermes** — a `providers.<name>` entry in `~/.hermes/config.yaml` with
`transport: chat_completions`, the base URL above, and any placeholder key.

**OpenHands** — `tools/incus/oh-start.sh` already reads these three variables;
point them at the endpoint and pass `--override-with-envs`:

```bash
LLM_BASE_URL=http://10.0.100.1:8080/v1
LLM_MODEL=openai/qwen
LLM_API_KEY=local
```

**Anything else** — any OpenAI-compatible client works with the base URL, model
id, and a placeholder key. If a harness needs a non-obvious step, add it here
and to `misc/agents/AGENTS.md` so the next agent finds it without asking.

## Server side

The service lives in `nix/nixos/hosts/home-server/modules/ai`
(`homeServer.ai`), on branch `home-server/local-ai-vulkan`. Host, port,
`servedName` and `contextSize` there must match
`nix/nixos/modules/home/programs/local-ai`. Switch the served model with
`homeServer.ai.model`, and keep `servedName` and the client `modelId` in step.
