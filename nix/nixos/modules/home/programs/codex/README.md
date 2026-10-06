# Codex CLI (DeepSeek)

Wires the Codex CLI to DeepSeek. The surface is small:

- `wrapper.nix` — provider config and `-c` overrides; `deepseek-flash` is the
  default, `codex-openai` is the escape hatch back to the base config.
- `catalog.nix` — produces `~/.codex/models.json`.
- `package.nix` — pins the official OpenAI Codex release binary (see below).

The API key comes from agenix (`deepseek-api-key`); it is read by the wrapper at
run time and never enters the store or `~/.codex/config.toml`.

## Why a catalog exists

Codex needs a model catalog to know a third-party slug's context window,
reasoning levels and tool support. `model_catalog_json` **replaces** the built-in
catalog wholesale, and every entry requires a non-empty `base_instructions`.

So an unknown slug without a catalog does not fail — it silently falls back to
Codex's default entry: the generic Codex prompt and a **272k** context window
instead of DeepSeek's **1M**. That is the whole reason this file is wired up.

## Where models.json comes from

DeepSeek does not publish the catalog as a standalone JSON file. It is embedded
in their setup script, so `catalog.nix` pins that script and extracts it at build
time, keeping only `deepseek-flash` and dropping the duplicated
`model_messages.instructions_template`. Nothing is vendored into this repo.

The extraction is deliberately brittle: if DeepSeek renames the heredoc marker
(`CODEX_MODELS_JSON`), the build fails instead of shipping a stale catalog.

## Updating the Codex client pin

`package.nix` pins the official release binary for `rust-v0.160.1`, the
`codex-x86_64-unknown-linux-musl.tar.gz` asset on the GitHub release. It is a
statically linked musl binary, so it needs no compiler and no upstream binary
cache — we just fetch and install it.

We deliberately do **not** use OpenAI's own `openai/codex` flake: it is a
development flake whose `packages` output does not build. Its
`cargoLock.outputHashes` omits git dependencies that `Cargo.lock` requires
(`appcontainer_common` and the rest of `microsoft/mxc`, `h3`, `h3-quinn`), so
`nix build github:openai/codex#default` fails while vendoring.

To bump to a new `rust-vX.Y.Z` release:

```sh
nix store prefetch-file --json \
  "https://github.com/openai/codex/releases/download/rust-vX.Y.Z/codex-x86_64-unknown-linux-musl.tar.gz"
```

Set `version` and `src.hash` (the returned `hash`) in `package.nix`, then
rebuild (`nixos-rebuild-switch`).

## Updating the catalog pin

When DeepSeek ships a new catalog, refresh the hash in `catalog.nix`:

```sh
nix store prefetch-file --json \
  https://cdn.deepseek.com/api-docs/codex-deepseek-setup-en.sh
```

Copy the `hash` value, then rebuild (`nixos-rebuild-switch`). Worth doing
occasionally: the catalog carries model metadata that changes with DeepSeek's
releases.

If the catalog's `minimal_client_version` outgrows the pinned client, bump the
client too (see above).
