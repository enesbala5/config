# Git history → storyline

Research step for `prepare-blog-article`. Run this when a repo, checkout, or
file/folder inside one is in play. The article still follows the skeleton and
voice in `SKILL.md`. History is evidence, not prose.

Current files = what the reader should copy.
Commits = why the obvious fix failed, what landed later as polish.

## 1. Resolve the repo

Collect candidate paths from the user, the draft, and any public-config link.

| Input | What to run |
| --- | --- |
| File | `git -C "$(dirname "$path")" rev-parse --show-toplevel` |
| Folder | `git -C "$path" rev-parse --show-toplevel` |
| GitHub/GitLab URL | Prefer a local checkout. If none, `gh` against that repo. Do not clone unless asked. |

The folder the user pointed at may **itself** be a git repo (nested checkout,
separate project). Always resolve from that path — do not assume the workspace
repo.

If `rev-parse` fails, walk parents for a `.git` directory. If there is no repo,
say so and ask for receipts. Do not invent history.

Do not SSH / `journalctl` / rebuild on a remote host to read git. Local
checkouts and `gh` against GitHub are fine.

When two repos are in play (portfolio vs the setup), mine the **setup** repo
unless the post is about the blog files themselves.

## 2. List history (narrow first)

Cap: ~40 log lines, then filter. Do not dump `-p` for a whole repo.

Referenced **file**:

```bash
git -C "$repo" log --follow --format='%h %ad %s' --date=short -- "$relpath"
```

First add (useful when the log is long):

```bash
git -C "$repo" log --follow --diff-filter=A --format='%h %ad %s' --date=short -- "$relpath"
```

Referenced **folder** (module, `scripts/utilities/`, a host):

```bash
git -C "$repo" log --format='%h %ad %s' --date=short -- "$relpath"
```

No paths yet, only a topic (`stylix`, `polarity`, `coolify`):

```bash
git -C "$repo" log --all --format='%h %ad %s' --date=short -i --grep='stylix\|polarity'
git -C "$repo" log --all --format='%h %ad %s' --date=short -- '*polarity*' '*stylix*'
```

`--grep` matches commit **messages**. Path globs match **files**. Use both.
Ignore rebuild / generation-table noise (see filters below).

## 3. Expand to sibling files

A referenced file is rarely the whole setup. For each mechanism-looking
commit, list what else changed:

```bash
git -C "$repo" show --stat --format='%h %s%n%b' "$hash"
```

Those extra paths (Nix module, keybind, `sudoers`, scheme file) become more
receipts. Repeat `git log --follow` on the ones that belong to this feature.

Read patches only for the shortlist (about 5–12 commits), not the full log:

```bash
git -C "$repo" show "$hash" -- "$relpath"
```

Follow renames. `--follow` is file-only; if a path moved, take the old name
from `--name-status` and keep going.

Remote-only (no local clone):

```bash
gh api "repos/$owner/$repo/commits?path=$relpath"
```

Then fetch a single commit if it looks relevant. Same filters as local.

## 4. Cluster into beats

Oldest first. Drop anything that is not this feature.

| Beat | What to look for | Article slot |
| --- | --- | --- |
| First landing | `--diff-filter=A`, "add X", initial script/module | Walkthrough (current form of that piece) |
| Failed / obvious approach | revert, "doesn't work", follow-up fix, dropped option | Main Challenge |
| Constraint | `sudo`, NOPASSWD, `/tmp`, `lib.mkForce`, hostname clash, reboot | Challenge, callouts |
| Required mechanism | specialisation, bind, unit, the script that actually switches | Solution + walkthrough |
| Later polish | wallpaper, `notify-send`, alias, extra app wiring after it already worked | Conclusion: optional vs required |
| Docs-only | `Add … docs`, notes, comments with no behavior change | Skip body; maybe Credits if it names a person |

A commit message is a hint. The **diff** decides. Terse messages (`Update X`)
still count if the patch introduces a mechanism.

### Keep

- New option, script, unit, keybind, `specialisation`, `mkForce`
- Workarounds and scope limits (passwordless sudo for two binaries only)
- Behavior that does not survive reboot, or does not reload until restart
- A later commit that exists *because* the previous version was not enough
  (e.g. Kitty had to move to `home-manager` so polarity actually stuck)

### Drop

- `nixos-rebuild` generation dumps / "Generation Build-date … Specialisation"
- Formatting, lockfiles, unrelated hosts, drive-by refactors
- Merge commits unless they are the only record
- Pure docs/notes unless they state the constraint in his words
- `wip` unless the diff is the mechanism

If the folder log is huge, do not summarize the whole directory. Narrow with
the feature name, a file glob, or ask which paths.

If history disagrees with what the user said, ask. Do not silently override.

## 5. Internal beat list (do not publish)

Keep this in the session. Do not paste it into the post.

```text
Repo: /home/e/config
Paths: scripts/utilities/toggle-polarity.sh

Beats (oldest first):
- [required] de9936d — toggle script (core switch)
- [docs]     bd6c54e — skip
- [polish]   9b3afcd — wallpaper on toggle
- [constraint] 5fd85ce — Kitty via home-manager so polarity sticks

HEAD files: <paths to quote in the walkthrough>
```

Map beats → sections, then write in the usual voice. No "in commit abc…",
no "that's when it clicked", no hash list, no changelog heading.

## 6. Worked example (this config repo)

User points at `~/config` or `scripts/utilities/toggle-polarity.sh`.

```bash
git -C ~/config log --follow --format='%h %ad %s' --date=short -- \
  scripts/utilities/toggle-polarity.sh
```

```text
9b3afcd 2026-05-21 Add wallpaper update at toggle-polarity script
de9936d 2026-05-21 Toggle Polarity - Light / Dark Mode toggle via specialization (stylix)
```

`git show --stat de9936d` also adds the light scheme. `git show --stat 9b3afcd`
also touches the Hyprland bind. `--grep=specialis` is mostly generation-table
noise — ignore it; the file log is the signal.

Storyline to use, not to print:

- Required: script + specialisation + passwordless sudo for the two
  `switch-to-configuration` paths
- Polish: wallpaper (and later, notifications) on toggle
- Messy reality: some apps still need a reload; Kitty needed `home-manager`
  instead of a symlink

That is the same split the Stylix post already makes in Conclusion. Extract
it from history so a new post can do the same without inventing the plot.

## 7. After mining

- Walkthrough quotes **HEAD**, with placeholders for reader-specific values
- Introduction names the constraint the first approach hit
- Main Challenge numbers the needs those commits were solving
- Callouts for reboot / scope / "that didn't work for me" when a later
  commit or message records it
- Conclusion: required mechanisms vs optional polish
- Public repo link still belongs in Introduction when the files live there
