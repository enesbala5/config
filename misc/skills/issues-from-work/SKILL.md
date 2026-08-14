---
name: issues-from-work
description: >-
  Turn a conversation plus local git changes into GitHub issues in a stored
  personal voice, then close what shipped and leave leftover work open. Use when
  the user names this skill, or asks to log work as issues, create GitHub issues
  for this work, backfill undocumented work, or close finished tasks so the repo
  has history.
disable-model-invocation: true
---

# Issues from Work

Backfill undocumented work as GitHub history. Write in the stored personal
voice. Draft first. Create and close only after the user says go.

Read [voice.md](voice.md) before drafting anything. Do not scrape this repo's
issues to rebuild tone. Do not use the `brand-voice` skill.

## When to use

- the user names `issues-from-work`
- "log this as issues" / "create github issues for this work" / "close these so we have the history"

## Workflow

```text
read voice.md (always)
        ↓
fetch open issues (dedupe + existing labels only)
        ↓
gather convo + prompts + git status/diff/log
        ↓
split into candidates, then recurse on deps / leftovers
        ↓
draft ledger in stored voice (do not create yet)
        ↓
user says go
        ↓
create parents first (so #N refs work) → create children → close shipped
```

### 1. Voice

Read [voice.md](voice.md). Same voice in every repo.

### 2. Dedupe and labels

```bash
gh issue list --state open --limit 50 --json number,title,body,labels
gh label list --limit 50
```

If an open issue already covers a candidate, skip it and point at that number.
Reuse a label this repo already has for this kind of work. Do not invent labels.
If none fit, omit `--label`.

### 3. Gather work

- this conversation and the user's prompts (verbatim where they named the tasks)
- `git status`, `git diff`, recent `git log`

Do not run commands on remote hosts. `gh` against GitHub is fine.

### 4. Split, then recurse

Candidates:

- **Close after create** — done in this convo / already in the diff
- **Leave open** — mentioned or implied, not finished
- **Skip** — already an open issue

Then scan each candidate for implied follow-ups (`needed for X`, leftover in
the convo, "what's left" after the diff). Add those. Repeat until nothing new,
or 2 hops. Do not invent work that was not in the convo or the diff.

### 5. Draft ledger (always, before `gh issue create`)

```text
Close after create
- Title
  body
  why done: …

Leave open
- Title
  body
  leftover: …

Skip (already exists)
- #N covers …
```

Stop. Wait for go.

### 6. Create, then close

After go:

1. Create parents first so child bodies can say `Needed for #N`.
2. Create children.
3. Close shipped issues with a short comment.

```bash
gh issue create --title "Setup smartd checks for home-server drives" --label enhancement --body "$(cat <<'EOF'
Need smartd on home-server watching the disks (nvme, toshiba, seagate usb) and telegram when something pops up.
EOF
)"

gh issue close 40 --comment "done, smartd is on and notifies via telegram"
```

Report the issue URLs.

## Example (verbatim user prompt)

```
create github issues for these tasks and then close them so we have the history of it logged in the repo

issue for smartd checks for the drives
add an issue for smartd acknowledgment
issue for telegram notify buttons etc. (reference the above issue, eg. needed for X

---

write very little on these, like just clear titles and maybe a very short description that is human like, not too length, clear and to the point, reference my prompts for this please, typo-s here and there are fine (but not on the title)
```

Target output is the three shipped issues in [voice.md](voice.md).

## Out of scope

- Auto-invoke
- Re-deriving voice from this repo's issues
- Changing GitHub issue templates or creating new labels
- Remote host commands (SSH, `nixos-rebuild` against a server, etc.)
