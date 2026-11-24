---
title: "Prepare Blog Article skill (verbatim archive)"
source: "enesbala5/config/misc/skills/prepare-blog-article/"
author: "config repo"
published: "n/a"
captured: "2026-11-24"
---

# Prepare Blog Article skill (verbatim archive)

Reproduced from the global skill at `misc/skills/prepare-blog-article/` before it was folded into the `copy` module. Every file below is reproduced without summarisation or editing; YAML frontmatter from SKILL.md is omitted here and recorded above.

## File: SKILL.md

# Technical blog posts

Write the kind of guide Enes actually publishes: a problem he hit, why the obvious
fix fails, then the setup that works on his machine — with enough receipts that a
reader on the same stack can follow it.

This is not a general "blog writing" skill. It is not the client-marketing register
in the SEO / template-vs-custom posts. Those are a different voice. Do not blend them.

## Canonical sources

Prefer the newer post as the quality bar. Use the older one for shared structure.

1. `src/posts/nixos-stylix-polarity-toggle.md` (2026) — current voice
2. `src/posts/coolify-setup-home-server.md` (2024) — same skeleton, looser prose

Do not copy typos, truncated comments, or stuffed keyword lists from the Coolify post.

Gold-standard snippets: [excerpts.md](excerpts.md)

## When to use

- New technical post, outline, or rewrite
- Editing a draft so it sounds like him instead of generic docs/AI
- Turning a working NixOS / homelab / self-hosting setup into a guide
- A repo, checkout, or file path is the source — extract the storyline from
  commits, not from a guessed walkthrough

## Before writing

Do not invent a walkthrough. This author writes from a setup that already works.

Collect, or ask for:

- Stack the reader already has (do not re-teach it)
- The painful part (slow rebuild, missing SSH, sudo prompt, no public IP)
- The end state in one sentence
- Real files, commands, paths, versions, distro
- What he skipped on purpose (upstream docs, unrelated setup)
- Credits (people, posts, videos he adapted)

If a repo or path inside one is in play, mine its git history first (see
**Repo storyline**). If receipts are still missing after that, outline the
skeleton and wait. Do not fabricate configs, keybinds, or "typical" Nix.

## Repo storyline

A referenced git repo is a receipt source, not just a link to paste.

Trigger when any of these show up: a local folder that is (or sits inside) a
git checkout, a specific file path, a GitHub/GitLab URL, or "my config" /
public-repo link in the draft. Resolve the repo from **that path**, even if
it is not the workspace (`git -C <path> rev-parse --show-toplevel`). Do not
SSH to a remote host to read history.

Mine **before** outlining:

1. File history for every referenced path (`git log --follow`)
2. Sibling files from those commits (`git show --stat`)
3. Topic search only if paths are still unknown (`--grep` / path globs)

Cluster commits into beats, oldest first: first landing → failed / reverted
approach → constraint (sudo, `/tmp`, `lib.mkForce`) → required mechanism →
later polish. Use that to fill Introduction (the painful part), Main
Challenge, callouts, and Conclusion (polish vs required). Walkthrough stays
on current HEAD files.

Do not paste hashes, `git log`, or a changelog into the article. Do not
narrate archaeology. Full command list and filters:
[repo-storyline.md](repo-storyline.md)

## Article skeleton

Body headings start at `# Introduction`. The page title comes from frontmatter —
do not repeat the title as the first H1.

```text
# Introduction
  Situation the reader is already in
  The painful / slow / annoying part
  Optional callout: inspiration, hard requirement, or scope limit
  What this article covers — and what it will not re-explain
  One-sentence promise of the end state
  Optional: link to the full public config

# The Main Challenge
  Why the obvious approach fails (rebuild, no .ssh/config in Docker, etc.)
  Numbered list of what the setup actually needs

## The Solution
  Map each need to a mechanism, in one tight block
  Then go to the walkthrough — do not keep explaining

# Process Walkthrough
## Key Requirements
  Numbered prerequisites
  "This guide assumes …" plus a link for anything out of scope

## 1. …
## 2. …
  Goal first, then the command or config
  Callouts for warnings, scope, and personal caveats
  Nested 1.1 / 1.2 only when a step is genuinely long

# Putting It Together
  Verification checklist (binary exists, script runs, keybind is stable, reboot behavior)

# Conclusion
  Restate the pattern as 4–6 mechanism bullets
  Optional polish vs required pieces
  Credits + where to get help
```

Older posts used `# Verify the Connection` instead of `# Putting It Together`.
Prefer the newer name.

## VOICE PROFILE

**Register:** first-person technical how-to. Competent peer, not teacher, not brand.

**Reader:** already on the stack (`NixOS` + `Stylix`, or Coolify + a home server).
Skip tutorial material that exists upstream.

**Stance:** "here is what I run." `you` for steps, `I` for choices, failures, and
paths. Name the distro and tools actually used.

**Rhythm:** medium sentences that name a mechanism then the reason. Short sentences
for constraints. Situation → dash → specifics is common.

> If you run `NixOS` with Stylix, you already get system-wide theming - GTK apps,
> terminals, Waybar, and a long list of other modules pick up your `base16` scheme
> and polarity automatically.

**Compression:** explain *why this constraint exists*, then give the command.
Do not narrate every keystroke. Do not "dive deep."

**Address:** conventional capitalization. Product names as proper nouns. Heavy
backticks on tools, flags, paths, options, and UI labels (`stylix.polarity`,
`Servers`, `host.docker.internal`).

**Parentheticals:** qualification and narrowing, not jokes. `(runtime switch, not
boot default)`, `(or at least home-manager switch)`, `(eg. Hetzner)`.

**Questions:** almost none. Never as a hook.

**Claims:** sharp on mechanisms (`lib.mkForce` is important — without it …).
Hedged on personal results (`that didn't work for me personally`). Name what
does *not* update instantly. Do not sell the setup as clean if it needs a workaround.

**Receipts:** real commands, file paths, systemd units, Nix, keybinds. Public repo
link when the files live there. Distro + version when it matters. Credit people
by name and handle.

**Transitions:** headings do the work. Then `Now that we have X…`, `After a rebuild
you should have:`, `That is exactly what you want for …`. No "that's when it clicked."

**Never:**

- fake curiosity (`Have you ever struggled with…`)
- `In this post we'll dive into` / `Let's get started` / `Without further ado`
- `Excited to share` / founder-journey filler / LinkedIn cadence
- `not X, just Y` / `no fluff` / `it's easier than you think`
- listicle titles (`5 ways to`)
- motivational wrap-ups
- invented configs presented as his
- emoji in prose (emoji in a `notify-send` string is fine if the real script has it)
- the SEO/template-post marketing voice
- generating visual assets (header/hero, thumbnail, OG image, diagrams-as-files)

## How to write each section

**Introduction.** Open on the reader's current setup, not a definition. Pivot to
the part that sucks. Scope out anything with good existing docs. End with the
end state (one keypress, Coolify can validate the server, …).

**Main Challenge.** Restate the constraint in technical terms. Number the
requirements the solution must hit.

**Solution.** One short mapping: mechanism → requirement. Then stop.

**Walkthrough.** Each step: goal in a sentence (or a `Goal:` callout), then the
snippet, then what you should see or why a flag exists. Keep placeholders obvious:
`[YOUR DOMAIN]`, `${data.username}`. Use his real paths when the post is "how I
did it" (`~/config/scripts/utilities/toggle-polarity.sh`). Show **HEAD** — the
setup that works now. Git history informs *why* a flag exists and what was
polish vs required; it does not become a changelog in the article.

**Putting It Together.** Imperative checklist a reader can run.

**Conclusion.** Pattern recap as bullets. Separate optional polish (wallpaper,
`notify-send`) from the required pieces. Thank named people. Point at docs /
Discord / the repo — not a CTA button.

## Callouts

GitHub/Obsidian callouts via `rehype-callouts`. Prefer a short title.

```markdown
> [!NOTE] Inspiration
> This approach is adapted from …

> [!info] Default generation = dark
> Because the base config already sets `polarity = "dark"`, …

> [!caution] Scope the commands tightly
> Only whitelist these two exact `switch-to-configuration` paths.

> [!warning] Does not survive reboot
> `/tmp` is cleared on reboot, so after a restart the script assumes dark …
```

Use them for: inspiration/credit, hard requirements, security scope, "keep this
running", distro-specific commands, personal trade-offs. Do not callout every paragraph.

## Code blocks

- Fenced, with a language tag
- Goal or one-line context *above* the block, not a recap below unless a flag needs it
- Show the file as he keeps it, then say what to change (`remember to update [YOUR DOMAIN]`)
- After rebuild/switch steps, show the path or command the reader should now have

Highlighter languages in the portfolio: `javascript`, `typescript`, `bash`, `json`,
`svelte`, `ini`, `properties`, `ssh-config`, `nix`. Stay on that list unless the
user asks to add a lang.

## Portfolio file contract

When writing into the portfolio repo, the post is `src/posts/{slug}.md`.

```yaml
---
title: Instant Light / Dark Mode switching on NixOS via Stylix and Hyprland
description: Toggle Stylix polarity instantly with NixOS specialisations.
metaTitle: Instant Stylix Themes on NixOS
metaDescription: Switch Stylix between dark and light instantly with NixOS specialisations, a toggle script, and a Hyprland keybind.
date: '2026-08-02'
updated: '2026-08-02'
tags:
  - linux
keywords: nixos, stylix, polarity, dark mode, light mode, hyprland, specialisation, base16, theme toggle, waypaper, home-manager
image: /images/blog/stylix-polarity/hero.svg
thumbnail: /images/blog/stylix-polarity/hero.svg
linkPreviewImage: /images/blog/stylix-polarity/og.png
published: true
---
```

Rules:

- `title`: readable, stack + outcome. Not a keyword dump. Newer post wins over Coolify's long title.
- `description`: one-line outcome (subtitle on the post)
- `metaTitle` / `metaDescription`: shorter / mechanism-named, for SEO tags
- `tags`: only values from `src/lib/info/tags.ts` (`linux`, `self-hosting`, `dev-ops`, …)
- `keywords`: comma-separated tools and outcomes, no duplicates
- `date` / `updated`: `'YYYY-MM-DD'`
- Images live under `static/images/blog/{folder}/` as `hero.svg` and `og.png` (also copied under `src/lib/assets/images/blog/` in this repo). **Do not generate any assets** — no header image, thumbnail, OG/social preview, SVG, PNG, or other illustration. Point frontmatter at the expected paths and note that the user still needs to add the files.
- `published: true` only when the user wants it live
- Optional `imageClassNames` appears on older marketing posts — omit on technical posts

Slug = filename without `.md`. Keep it short and literal (`nixos-stylix-polarity-toggle`).

## Draft checklist

- [ ] Opens on the reader's setup, not a definition or hook question
- [ ] Names the constraint and why the obvious fix fails
- [ ] Scopes out well-documented prerequisites
- [ ] Walkthrough is his real files/commands, with placeholders for reader-specific values
- [ ] If a repo or file path was in play, git history was mined and the storyline
      (failed approach, later polish) shows up in Challenge / callouts / Conclusion
      — not as a commit dump
- [ ] Callouts used for warnings/scope/inspiration, not decoration
- [ ] Messy reality is named (what does not reload, hostname already in use, `/tmp` on reboot)
- [ ] Conclusion is a mechanism list + credits, not a pep talk
- [ ] No banned tropes, no marketing-post voice, no invented setup
- [ ] Frontmatter matches the contract when writing into the portfolio
- [ ] No generated image/thumbnail/OG assets; only path placeholders in frontmatter

## Additional resources

- Calibration snippets: [excerpts.md](excerpts.md)
- Git history → storyline: [repo-storyline.md](repo-storyline.md)

## File: excerpts.md

# Excerpts

Short patterns from the canonical posts. Match this rhythm; do not paste these
into a new article.

Source 1 = `nixos-stylix-polarity-toggle.md` (prefer).
Source 2 = `coolify-setup-home-server.md`.

## Situation open

Source 1:

> If you run `NixOS` with Stylix, you already get system-wide theming - GTK apps, terminals, Waybar, and a long list of other modules pick up your `base16` scheme and polarity automatically.
>
> The difficult part is switching between dark and light. A full rebuild just to flip `stylix.polarity` is too slow for something you might want several times a day. Typing a password every time you toggle is also annoying.

Source 2:

> If you use Coolify and also own a home server, you might find yourself in a situation like this - you rent a Remote VPS (eg. Hetzner), which is running a Coolify instance. You may have noticed the `Servers` feature in your Coolify instance, and thought about connecting your existing home server, so that it helps serve requests to your user and speeds up the build process, etc..

## Scope skip + promise

Source 2:

> There are many guides online for setting up `Cloudflare Tunnels` and creating a `Zero Trust Access Application` to expose SSH to a subdomain of your choosing - so I will not explain the steps in this article.

Source 1:

> In this article I'll walk through how I set up an instant dark / light toggle with NixOS, Stylix, and Hyprland. A single keypress flips polarity, swaps the wallpaper, and reloads Hyprland without prompting for a password.
>
> My complete NixOS setup is open source on GitHub - including the files used in this setup.

## Challenge → numbered needs → solution map

Source 1:

> `Stylix` is declarative. Your polarity lives in the Nix config, so changing it normally means editing the file and running `nixos-rebuild switch` (or at least `home-manager switch`). That works, but it is not a "press a key and the desktop flips" workflow.
>
> What we need instead:
>
> 1. Both themes available on the same system generation
> 2. A way to activate one or the other without a rebuild
> 3. No `sudo` password prompt on every toggle
> 4. A keybind (and optionally a shell alias) that runs the switch
>
> NixOS `specialisation`s solve (1) and (2). You declare a light (and optionally dark) specialisation that only overrides `stylix.polarity` / `base16Scheme`. Each generation then ships with switchable variants under `/run/current-system/specialisation/...`.
>
> Passwordless `sudo` for the two `switch-to-configuration` paths solves (3). A short bash script plus a Hyprland bind solves (4).

## Callout as personal trade-off

Source 1:

> [!warning] Does not survive reboot
> `/tmp` is cleared on reboot, so after a restart the script assumes dark (which matches the boot default). That trade-off is fine for me - the system boots dark, and the marker only matters within a session.

## Name what does not just work

Source 1:

> After the switch + `hyprctl reload`:
>
> - Many Stylix-aware apps pick up the new theme immediately (browsers often flip, Obsidian reacts, Kitty usually does too)
> - Some terminals may need a soft reload (e.g. Ghostty: `Ctrl+Shift+,`)
> - Apps like LibreOffice, Firefox, or Thunar often need **all instances closed** before the new polarity sticks

Source 2:

> Note: It's possible to use alternate usernames besides root but that didn't work for me personally and created issues with the `sudoers` file
>
> [!info] You may get the issue "Hostname / Domain already in use"
> I went ahead and ignored it, everything worked fine. If anyone has a better solution, please let me know in the comment section.

## Conclusion as mechanism list

Source 1:

> NixOS specialisations turn a normally rebuild-heavy Stylix polarity change into something you can bind to a single key. The pattern is small:
>
> - Base config stays dark
> - A `light` specialisation overrides polarity + scheme
> - Passwordless sudo only for the two switch binaries
> - A `/tmp` marker + script for toggle state
> - A Hyprland keybind to run it
>
> Wallpaper and `notify-send` are optional polish, but they make the switch feel intentional instead of silent.

## Credit

Source 2:

> I want to thank **Darren** (@frostfelll) - a Community Expert from Coolify's Discord
>
> He was very helpful and proposed the SSH tunnel solution to me. Couldn't have prepared this article without some of his tips.

Source 1:

> This approach is adapted from a Vimjoyer setup that uses NixOS `specialisation`s for light mode, plus a small bash script to switch between them. I ported it to `Hyprland` and added wallpaper + notification polish on top.

## File: repo-storyline.md

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
