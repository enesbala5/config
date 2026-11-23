# Module anatomy

This is the canonical structure. All of it is self-contained in this skill — do not read another module to learn it.

## Scope determines the roots

`<config>` is the verified config checkout; `<repo>` is the working repository
root. Global modules usually span two repositories; local modules do not.

| Piece | Global | Local |
| --- | --- | --- |
| Router skill | `<config>/misc/skills/<name>/SKILL.md` | `<repo>/.agents/skills/<name>/SKILL.md` |
| Workspace | `<config>/misc/modules/<name>/` | `<repo>/misc/<name>/` |
| Evidence guide | `<config>/misc/guides/<topic>/` | `<repo>/misc/guides/<topic>/` |
| Per-project records | `<repo>/misc/<name>/` | `<repo>/misc/<name>/` |

Write roots as tokens, never as machine paths. Do not link across the two roots
with Markdown links: name the other root's path in backticks instead.

### Records rule

A global module is shared across projects, so its workspace holds no per-project
state. Drafts, decisions and reviews go under `<repo>/misc/<name>/` in the
**working** repository — the same shape coverlttr uses for `misc/design/` and
`misc/video/`. Projects from different repositories therefore never mix. The
global workspace names that path; it never reads from or links into another
repository. Local modules keep records beside their workspace at
`<repo>/misc/<name>/`.

## Core (every module)

Router: `<config>/misc/skills/<name>/SKILL.md` (global) or
`<repo>/.agents/skills/<name>/SKILL.md` (local).

Workspace: `<config>/misc/modules/<name>/` (global) or
`<repo>/misc/<name>/` (local).

```
<workspace>/
├── AGENTS.md                         # hard gates + read-chain only
├── README.md                         # workspace index: intents, layers, records
├── intents/
│   └── <intent>/README.md            # one folder per intent, entry file
└── LEARNINGS.md                      # findings from real work, with status
```

## Optional layers (add only when justified by the purpose)

```
<workspace>/
├── pipeline/
│   ├── README.md                     # stage -> guide-bucket routing index
│   └── <stage>/README.md             # one per stage, adds/overrides only
├── projects/                         # per-target records when work is stateful
│   └── README.md                     # record shape + index convention
├── references/                       # capture formats and templates
│   └── README.md
└── rules/                            # reusable rule sets when there are many
    └── README.md
```

Templates for every file above live in [`../templates/`](../templates/).

## What each file owns

| File | Owns | Never contains |
| --- | --- | --- |
| Router `SKILL.md` | Intent table + one file to read; root-anchored path tokens | Rules, gates, implementation steps, `../` chains |
| `AGENTS.md` | Hard gates, where records live, read-chain, authority, approval | Task instructions, lesson content |
| `intents/<intent>/README.md` | The sequence for one intent, its gates and handoffs | Other intents' flows, duplicated gates |
| `pipeline/README.md` | Stage → lesson-bucket routing | Lesson content |
| `rules/<...>` | What must be true, with pointers to lesson evidence | Copies of lesson prose |
| `LEARNINGS.md` | Findings from real work, with status | Guide lessons, final rules |

## Read-chain

A nested file does not link to its parents or claim a parent "applies". The reader loads, in order: workspace `README.md` → `AGENTS.md` → relevant index (`pipeline/README.md`) → stage → guide root README → bucket README → named lesson. Cross-file references use `<config>` / `<repo>` token paths, not `../` chains. A nested file only **adds or overrides**; if a rule is missing in the leaf, the nearest ancestor still holds. Never read a whole bucket and never open a second sibling branch for the same question.

## Extension points

| Change | Cost |
| --- | --- |
| New lesson in the guide | Zero module edits — rules point to buckets |
| New intent | One folder + one router row + one `AGENTS.md` pointer |
| New stage/axis | One `pipeline/` folder + one row |
| New rule set | One file in `rules/` + one index line |
| New finding | One `LEARNINGS.md` entry with status |
