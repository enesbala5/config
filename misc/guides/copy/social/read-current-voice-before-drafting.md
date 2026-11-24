# Read the current voice source; never draft from memory

**Feeds stage:** social

Voice and messaging files live in external repos and change. Read them fresh
through the shared cached reader before drafting — never rely on memory of what
they say, and never make a fresh clone or a per-file API call for each run.

The cache owns its own refresh policy: clone once, refresh only when stale,
read the rest from disk, and let one shared cache serve every skill that uses
those files so a single refresh is enough. A failed refresh is not a failure —
serve the cached copy, warn once, and keep working. Stale voice docs beat no
voice docs. Durable facts belong in the source repo, not in a skill.

Counterexample: drafting from a remembered summary of the tone file because
"it probably has not changed" — the exact mistake the cached reader exists to
prevent.
