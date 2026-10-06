# Codex CLI (DeepSeek)

Wires the Codex CLI to DeepSeek. The surface is small:

- `wrapper.nix` — provider config and `-c` overrides; `deepseek-flash` is the
  default, `codex-openai` is the escape hatch back to the base config.
- `catalog.nix` — produces `~/.codex/models.json`.
- `package.nix` — takes the Codex CLI from OpenAI's own flake, pinned to a
  release tag in `flake.nix` (see below).

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

The client is OpenAI's own package, from the `codex` flake input in
`flake.nix`, pinned to the release tag `rust-v0.160.1`. That flake reads the
version from `codex-rs/Cargo.toml` and builds the workspace with its own pinned
nixpkgs and rust-overlay toolchain, so the client tracks upstream directly
instead of nixpkgs-unstable's lagging `codex`.

To bump to a new `rust-vX.Y.Z` tag, edit the URL in `flake.nix`, then:

```sh
nix flake update codex     # from nix/nixos/
```

and rebuild. If `codex-rs/Cargo.lock` changed, upstream's own
`cargoLock.outputHashes` build fails; fixing that is theirs to do in their
flake.

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
