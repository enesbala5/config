# Providers

External backends this module uses. A provider is a backend that supplies
something the work needs — a generated asset, a transcription, a hosted file.
This index says what each one supplies, how it is reached and what it costs.
Workflow rules and approval gates live in the workspace `AGENTS.md`, never here.

## Entries

| Provider | Supplies | Reached through | Spend |
| --- | --- | --- | --- |
| `earshot` | Catalogue rendering (`make`, `make-set`), builds from parts, recipes/cookbook, and listening judges (realness, rank, match, find, measure, timeline, sheet, critique). No model generates audio. | Python package installed from GitHub, pinned as `earshot @ git+https://github.com/Leonxlnx/earshot` (not the PyPI name); CLI `earshot ...`, MCP server `earshot mcp`, API `from earshot import api`; verify with `earshot doctor`. Install `listen`/`mcp` extras for listening. | Base ~350 MB CPU, no model for making. Listening extras ~1.1 GB download / 2.2 GB on disk on first use. `llm` critique sends mono audio to Google and needs a key plus explicit user consent. |
| `real-sound` | Real-recordings soundtrack pipeline: `analyze`, `audit` with `licences`, `arrange`, `mix`, `qa`, `variant`, `credits`, `master`, `mux.mjs`, plus `python -m earshot` listening. | One Python interpreter with numpy, scipy, soundfile and `earshot` (the earshot venv); run scripts with `-I` so downloads cannot shadow modules; `scripts/licences.py` is the imported policy module, other scripts print `--help`. | Real-recording sourcing and licence clearance; deterministic CPU render. No per-call fee declared here; attribution cost is carried into credits and the video description. |

A new backend is added with `extend` (`target: provider`) and documented in this
index with the same four columns. Provider docs never hold project data,
credentials or signed URLs.
