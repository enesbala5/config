# OpenHands path-triggered rules

OpenHands does not read `.cursor/rules/*.mdc`, but it does load `.agents/skills/`:
a `.md` file with no `paths:`/`triggers:` frontmatter is loaded in full, always.
That means the Cursor rules under `misc/rules/general/` and `misc/rules/web/` can be
shipped to OpenHands as-is, so this directory holds **only** the rules that need
extra OpenHands-specific path info:

| File | `paths:` |
| --- | --- |
| `svelte-state-typing.md` | `**/*.svelte`, `**/*.svelte.ts`, `**/*.svelte.js` |
| `component-folder-structure.md` | `frontend/**/*.svelte` |

Everything else is not duplicated here. Their Cursor sources become always-on
OpenHands rules directly, because a file without a trigger is always active:

| Cursor source | OpenHands form |
| --- | --- |
| `general/behavioral-guidelines.mdc` | always-on (source shipped as `behavioral-guidelines.md`) |
| `general/command-environment.mdc` | always-on |
| `general/commit-message.mdc` | always-on |
| `general/ask-before-remote-hosts.mdc` | always-on |
| `general/no-agent-prefixes.mdc` | always-on |
| `general/principles.mdc` | always-on |
| `web/prefer-undefined-over-null.mdc` | always-on |
| `web/svelte-state-typing.mdc` | overridden by `svelte-state-typing.md` here |
| `web/component-folder-structure.mdc` | overridden by `component-folder-structure.md` here |
| `web/frontend-design.mdc` | not a rule: it is the skill `misc/skills/frontend-design/` |

`alwaysApply` and `globs` are Cursor-only keys. OpenHands ignores unknown
frontmatter keys, so the sources need no rewriting: a rule is scoped only when it
declares `paths:` (or `triggers:`). The `paths:` files here override their
same-named Cursor source at push time.

`frontend-design` is excluded from the push (see `EXCLUDED_RULES` in
`tools/incus/agent-vm-manage.sh`) because it is already a skill under
`misc/skills/`.

## Syncing

`tools/incus/agent-vm-manage.sh` pushes every `*.md` and `*.mdc` under
`misc/rules/` recursively to `/root/.agents/skills/` in the agent VM, renaming each
to `<name>.md`. The guest's OpenHands agent server runs as root with `HOME=/root`
(see `nix/nixos/hosts/home-server/modules/incus-ai-agent/default.nix`), so
`~/.agents/skills/` is the user scope that applies to every conversation on that VM.

Run it after changing a rule:

```bash
tools/incus/agent-vm-manage.sh push-rules
```

A VM `start` runs the same sync. Start a new conversation afterwards so OpenHands
rebuilds its skills catalog; existing conversations keep the rules they already
loaded.

## Adding rules

Add the rule to `misc/rules/` as usual; it is picked up automatically. Only add a
file here when the rule needs an OpenHands `paths:` scope that Cursor's `globs:`
cannot express.
