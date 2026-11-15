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
| Model id | `qwen` (Qwen3-4B abliterated, Q4_K_M) |
| API key | none — send any non-empty placeholder |
| Context | 16384 tokens, one slot (after rebuilding server and clients) |
| Tools | function calling works (`tools` + `tool_choice`) |
| Thinking | Qwen3 hybrid; off by default via `chat_template_kwargs` |

Reachability: `home-server` resolves over Tailscale MagicDNS
(`100.88.203.12`), and the port is open only on `tailscale0`. The tailnet must
be up on the client. LAN clients need `homeServer.ai.openFirewall = true` on
the server first. Incus guests reach the host at `10.0.100.1` because
`incusbr0` is a trusted interface — no firewall change needed.

## Rules of thumb

- **Turn thinking off for agent loops.** Qwen3 thinks by default and spends
  much of the context window on `reasoning_content` before answering. Send
  `"chat_template_kwargs": {"enable_thinking": false}`; `ask-local` and the
  pi provider already do. The served abliterated GGUF is a merge of the hybrid
  Qwen3-4B, so it keeps the same template and the same rule.
- **One request at a time.** The server runs `--parallel 1`; concurrent
  requests queue rather than sharing context.
- **16K is the total window, not the usable input.** pi's own prompt measured
  19198 tokens with MCP servers and skills loaded — still too large, before
  reserving room for an answer. `pi --no-mcp --tools read,bash` cuts it down;
  the HTTP 400 reports the new size.
- **The model stops reading early.** A 6012-token input split across two files
  got a summary of the first file only. Keep inputs under roughly 3-4K tokens
  when the answer depends on all of it.
- **Capability.** Good at short, well-scoped single-turn jobs. Do not expect
  multi-step refactors or long tool chains to hold together. Abliteration costs
  a little instruction-following and tool-call fidelity against stock Qwen3-4B.

## Verify

```bash
curl -s http://home-server:8080/health                     # {"status":"ok"}
curl -s http://home-server:8080/v1/models                  # id: "qwen"
curl -s http://home-server:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen","messages":[{"role":"user","content":"Say OK."}],
       "max_tokens":32,"chat_template_kwargs":{"enable_thinking":false}}'
```

## Single-shot helper (`ask-local`)

`scripts/utilities/ask-local` runs one prompt with no harness in the middle, so
skills work without pi:

```bash
ask-local "explain: unshare: mount --make-rprivate failed"
git diff | ask-local --skill chunk-and-commit "propose the commit chunks"
ask-local --skill copy-editing --max-tokens 600 < draft.md
```

It reads the instruction from arguments and the data from stdin, loads
`~/.agents/skills/<name>/SKILL.md` for `--skill`, turns thinking off, and counts
the prompt with the server's own `/tokenize` before sending. If the prompt will
not fit it exits with the numbers instead of letting llama-server return 400.

This is the right shape for skills against a small local model: the skill text
is a few thousand tokens, the answer is one turn, and nothing else competes for
the window. Multi-turn skills (chunk-and-commit over a real working tree) still
want a hosted model and a full harness.

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
`homeServer.ai.model` — catalog: `qwen-abliterated` (current, abliterated
Qwen3-4B that keeps thinking), `qwen` (stock Qwen3-4B), `mistral`, `deepseek`.
Only the selected entry is downloaded, and downloaded weights stay in
`/var/lib/ai/models`, so switching back is one line plus a rebuild and no
re-fetch. Keep `servedName` and the client `modelId` in step; `servedName` is
pinned to `"qwen"` on the server so a swap does not rename the endpoint for
any client. Set `modules.home.localAi.thinking` to match the served template.

The configured default is 16K with `q4_0` K/V cache and flash attention. This
targets roughly the cache memory of the previous 8K/`q8_0` configuration;
it is not a guarantee of Vulkan support, VRAM residency or answer quality.
Rebuild the server and clients before using the larger window. Verify
`GET /props` reports `default_generation_settings.n_ctx = 16384`, then test
a prompt over 8K and check GPU memory and response quality. Longer context
does not fix the early-reading limitation observed above.

If startup fails or quality regresses, restore `homeServer.ai.contextSize = 8192`
and `homeServer.ai.kvCacheType = "q8_0"`, set the client context window back
to 8192, and use `LOCAL_LLM_CTX=8192` with `ask-local`.
