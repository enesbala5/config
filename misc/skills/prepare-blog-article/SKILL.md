---
name: prepare-blog-article
description: >-
  Write technical how-to blog posts in Enes's voice: reader situation, the
  real constraint, then a working setup with commands, configs, callouts, and
  named trade-offs. When a repo, checkout, or file path is referenced, mine
  its git history for the storyline (failed approaches, later polish). Use
  when drafting, editing, outlining, or rewriting blog posts, especially
  Linux, NixOS, Hyprland, self-hosting, Coolify, or homelab guides.
  Canonical sources are the Stylix polarity and Coolify home-server posts.
---

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
