---
title: "Draft X Posts skill (verbatim archive)"
source: "enesbala5/config/misc/skills/draft-x-posts/"
author: "config repo"
published: "n/a"
captured: "2026-11-24"
---

# Draft X Posts skill (verbatim archive)

Reproduced from the global skill at `misc/skills/draft-x-posts/` before it was folded into the `copy` module. Every file below is reproduced without summarisation or editing; YAML frontmatter from SKILL.md is omitted here and recorded above.

## File: SKILL.md

# Draft X posts

Hand Enes ready-to-post X options built from his own recent work plus one topical angle, aimed at a named account. He posts manually. Nothing here posts, schedules, or scrapes.

## When to use

- The scheduled batch (11:00, 14:00, 17:00, 20:00 Europe/Tirane) or any ask like "what should I post", "post ideas for X", "draft a post about X".
- Schedule note: the cron job runs `0 9,12,15,18 * * *`, and cron is UTC. That is 11:00, 14:00, 17:00, 20:00 local in CEST. When Albania moves to CET on the last Sunday of October the expression shifts one hour earlier, to `0 10,13,16,19 * * *`.
- One target on request, or the full batch of two targets.
- Not for replying to someone else's post (that is `comment-response`) and not for Reddit (that is `coverlttr-x-organic-replies`).

## Target = who we are speaking as

| Target | Account | Voice reference |
| --- | --- | --- |
| `personal` | @enesbala_ | [references/personal.md](references/personal.md) |
| `coverlttr` | @coverlttr | [references/coverlttr.md](references/coverlttr.md) |

Read the target reference before drafting. The two never blend: a Coverlttr idea on the personal account is a story about building it, on the brand account it is a product claim. Adding a target means adding one reference file and one row here.

## Voice sources are cached, never re-cloned

Voice files live in his GitHub repos. Read them through the cached reader: never a fresh clone per run, never a per-file `gh api` call.

```bash
bash scripts/repo-file.sh enesbala5/portfolio main misc/TONE.md misc/PROFILE.md
bash scripts/repo-file.sh enesbala5/coverlttr dev docs/marketing/messaging.md docs/marketing/voices/precise-advocate.md
```

Clone once, pull at most once per TTL, read from disk, keep working if the pull fails. The full contract is in [references/repo-cache.md](references/repo-cache.md). `comment-response` calls the same script as `../draft-x-posts/scripts/repo-file.sh`, so one cache and one pull serve both skills.

## Material

```bash
bash scripts/recent-work.sh 36
```

Prints commits and merged PRs across `portfolio`, `coverlttr`, `merre`, `lune`, `config` from the last 36 hours, newest first, and says so explicitly when a repo has nothing. That output is the build-in-public pool: pick the change with a real story behind it (a decision, a bug, a trade-off, a thing he learned), not the change with the biggest diff.

Topic material comes from `web_search`, at most two queries per batch, in the lanes he actually has standing in: cover letters and hiring, AI tooling for developers, Albanian ecommerce and marketplaces, NixOS and self-hosting. A topical option is only valid when the item is real, recent, and he has a non-obvious take. Its `from:` line names the outlet and the date exactly as they appeared in the search output, because that line is the only way he can check the item later. An item that cannot be tied to a source the search actually returned does not ship, and a paraphrase dressed up as reporting is not a source. If nothing qualifies, ship a third build-in-public option instead and say so in one line.

## Batch composition

Four options: two for `personal`, two for `coverlttr`. Across the four: two built from his own recent work, one topical or reaction option, one free slot that goes to whichever signal is stronger that day (tie-break: his own work). Never four ideas from one commit. When a target has no fresh work in the window, that target's build option comes from its own docs: a mechanism worth explaining out of the product summary, or a case-study fact. The `from:` line says which.

Before drafting, read the last 200 lines of the ledger and drop any commit, PR, or angle already delivered in the previous 14 days. A repeated angle is worse than a thin batch.

## Hard rules

1. No em dashes or en dashes. Commas, or restructure.
2. No URLs in the post text, for either account. The link lives in the bio; a launch post can note that the link goes in the first reply.
3. One post per option: 280 characters or fewer. When the story genuinely needs more, a numbered thread of two to three posts, each 280 or fewer. Never a wall of text.
4. No hashtags. No "Excited to share", no fake curiosity hooks, no growth-hacker cadence, no engagement bait.
5. No invented metrics, clients, awards, or dates. Every concrete claim traces to TONE.md, PROFILE.md, the Coverlttr docs, or a commit that is actually in the material.
6. No overclaims: never "ATS-proof", never guaranteed interviews, never celebrating mass applying.
7. One ask maximum per option, and only when it is real (feedback on a screen, a question he wants answered).
8. Reread the target reference's banned list before the self-check. The personal and brand registers have different bans.

## Output contract

Telegram message, nothing before it and nothing after it:

```
X posts, 4 options

1. personal, @enesbala_
from: portfolio 3441294, personal brand docs
<draft>
(241 chars)

2. personal, @enesbala_
from: topical, hiring news
<draft>
(198 chars)

3. coverlttr, @coverlttr
voice: Precise Advocate, from: messaging.md
<draft>
(263 chars)

4. coverlttr, @coverlttr
voice: Application Operator, from: coverlttr commits
<draft>
(221 chars)
```

The draft is copy-paste ready: plain text, no quotes around it, no markdown decoration, no code fence. One `from:` line per option naming the source, kept to a few words. No preamble, no process narration, no offer to do more. The ledger is the only archive: no batch files, no reports, no scratch documents written to disk.

A full batch that shipped, with the source line for each option: [references/example-batch.md](references/example-batch.md).

## Procedure

1. Read the target references for the accounts in the batch. Done when both registers are loaded and the banned lists are in hand.
2. Fetch the voice sources through `scripts/repo-file.sh` (one call per repo, paths listed in the reference). Done when TONE.md and the Coverlttr docs are in context.
3. Run `scripts/recent-work.sh 36`. Done when there is a shortlist of candidate changes with a story.
4. Read the ledger tail and drop repeats. Done when no candidate collides with the last 14 days.
5. Search for the topical option, or decide to skip it. Done when the item is dated within the last week and the take is his, not a summary.
6. Draft the four options against the target references and the hard rules.
7. Self-check, then append to the ledger.

## Self-check

- Dashes and links, mechanically:
  ```bash
  grep -nP '[\x{2013}\x{2014}]|https?://|\bwww\.' drafts.txt
  ```
  Empty output is the pass. Any hit is a fail, fix and re-run.
- Every claim traceable to a file just read or a commit in the material output.
- Personal options sound like Enes, not a brand; brand options use one register, not a blend of three.
- Both accounts represented, four options, each with its `from:` line.
- Would a stranger read the brand options as an ad, or the personal ones as a growth thread? Rewrite if so.
- Ledger appended at `~/.hermes/x-posts/delivered.jsonl`, one object per option:
  `{"id": "<repo>:<sha|slug>", "target": "personal", "voice": "-", "angle": "<one line>", "text": "<draft>", "at": "<ISO8601>"}`

## Pitfalls

- Drafting from memory of the voice files. They change, and the cached reader exists so there is no excuse.
- Reposting the same commit under a new opener. The ledger is keyed on ids and angles for exactly this reason.
- Treating a commit message as a story. `Fix OG image filename` is not a post; the reason behind it can be.
- Brand copy on the personal account. That is the fastest way to make his feed look like a product feed.
- Inventing the topical option. A weak batch of three honest options beats a fabricated news reaction.
- Padding to hit the register he uses on big recaps. Those came from events that actually happened; if the material is thin, write the short post.
- Em dashes in the batch message itself. The grep covers the drafts; the surrounding message is still his copy.
- A pull on every run. `repo-file.sh` owns the TTL; do not call `gh api` or `git clone` in parallel with it.

## Verification

1. Four options, two per target, every draft under the character rule and free of dashes and URLs.
2. `grep` self-check returns nothing.
3. Every `from:` line names something that appears in the material output.
4. Ledger has four new lines with today's timestamp.

## File: references/coverlttr.md

# Target: coverlttr (@coverlttr)

Speaking as the product on the brand account. Enes's personal register does not apply here, and brand copy never goes on the personal account.

## Sources

The marketing docs live on the `dev` branch. `master` does not carry them.

```bash
bash scripts/repo-file.sh enesbala5/coverlttr dev \
  docs/marketing/messaging.md \
  docs/marketing/brand-voices/precise-advocate.md \
  docs/marketing/brand-voices/candid-career-strategist.md \
  docs/marketing/brand-voices/application-operator.md
```

- `docs/marketing/messaging.md` is the allocator: which voice goes with which surface, and the prepare-versus-generate rule.
- `docs/marketing/brand-voices/*.md` are the three registers. Load all three, then use exactly one per post.
- `docs/marketing/market-positioning.md` and `docs/marketing/audiences/<segment>/index.md` when the post speaks to one audience in particular.
- `docs/marketing/campaigns/<name>/positioning.md` when the post is campaign copy.
- Product truth when a post needs a mechanism or a feature: `enesbala5/portfolio main "src/routes/work/(projects)/coverlttr/misc/summary.md"`.

## Register selection

| The post is about | Voice |
| --- | --- |
| Default: proposition, product explanation, pricing, general | Precise Advocate |
| Screening frustration, rejection, silence, confidence, onboarding, support | Candid Career Strategist |
| MCP server, Chrome extension, workflow, technical mechanisms | Application Operator |

Do not average the three. One baseline per post, and the register changes only because the topic calls for it. Useful line from the allocator: Precise Advocate states the case, Candid Strategist reduces anxiety, Application Operator explains the workflow.

## Rules that come from the docs

- **Prepare versus generate.** The applicant prepares a letter; the system generates a draft. Never collapse the two into "generate", and never describe the product as an AI letter generator: that is the category the positioning is trying not to own.
- **Precise Advocate** states what Coverlttr examines, connects, or produces. Mechanisms over superlatives. Vocabulary: fit, evidence, role, requirements, argument, specific, tailored, refine, send.
- **Candid Career Strategist** is honest and practical, never sentimental: you already have the experience, the challenge is showing why it matters for this role. Vocabulary: show, connect, clarify, strengthen, credible, ready.
- **Application Operator** is compressed and technical, skeptical of busywork: upload once, pull the listing, find the evidence, inspect, revise, export. Vocabulary: pull, match, extract, inspect, reuse, revise, export, ship.

## Never

- Promise interviews, hires, or ATS passage. Never "perfect", "game-changing", "ATS-proof".
- AI hype, inflated urgency, "10x", productivity-bro language, application-spam celebration.
- Talk down to applicants, blame them for an opaque hiring process, or exploit rejection anxiety.
- Fake curiosity hooks, motivational filler, "Excited to share".
- Present ATS alignment as an exploit, or hide that the user reviews the draft.
- URL in the post text. The link is in the bio; a launch post can note that it goes in the first reply.

## File: references/example-batch.md

# Shipped batch (first live run, 2026-09-12)

Format reference, not material. Every angle below is already in the ledger, so none of it should be reused.

```
X posts, 4 options

1. personal, @enesbala_
from: config PR 56, Incus network activation
Enabled Incus on the home server. The next nixos-rebuild broke: the Incus network activation ran inside the rebuild and the switch failed before it finished. Keeping that activation out of the rebuild path made it clean again. Check the order before blaming the package.
(270 chars)

2. personal, @enesbala_
from: topical, CV-Library study via The Star, 11 Sep
A UK survey this week found candidates rewriting CVs and cover letters for the screening software instead of the recruiter. I get the impulse. But you cannot optimize against a score you never see, and a human still reads it for evidence. Tailor for the role, not the robot.
(274 chars)

3. coverlttr, @coverlttr
voice: Precise Advocate, from: messaging.md
Coverlttr generates a draft. You prepare the letter. The split is deliberate: the mechanical part belongs to the tool, the judgment stays with you. A letter for one role comes from your evidence and the requirements as written, and stays editable before you send.
(263 chars)

4. coverlttr, @coverlttr
voice: Application Operator, from: coverlttr summary.md
Upload the CV once. Pull the listing, and Coverlttr matches your experience against the requirements it states, then builds a draft you can inspect and revise. Export is LaTeX based, so PDF, DOCX and plain text are the same letter. Cost shows before a draft runs.
(263 chars)
```

What the shape gets right:

- Four options, two per account, header line first, nothing around the message.
- Every character count is measured, not estimated, and all four are under 280.
- No dashes, no URLs, no hashtags, and each option makes one point.
- The source line is short and specific: repo plus the thing, or outlet plus date. Option 1 is a change that actually shipped, option 2 is a survey he can look up, options 3 and 4 are docs because neither account had fresh code in the window.
- Personal options read as his, not as brand copy. Brand options each pick one register and stay in it.

## File: references/personal.md

# Target: personal (@enesbala_)

Speaking as Enes, the builder, on his own account. First person, no brand voice, no marketing register.

## Sources

Fetch before drafting, cached (never a fresh clone):

```bash
bash scripts/repo-file.sh enesbala5/portfolio main \
  misc/TONE.md misc/PROFILE.md \
  "src/routes/work/(projects)/coverlttr/misc/summary.md"
```

- `misc/TONE.md` is the source of truth for this target: voice characteristics, post shapes, banned patterns, platform notes.
- `misc/PROFILE.md` holds the facts that are safe to cite (clients, products, hackathon wins, teammate and organizer names) and the weighting of his writing samples.
- The coverlttr `summary.md` is product truth, needed only when the post mentions Coverlttr.
- Voice samples when the register matters: `src/posts/coolify-setup-home-server.md` (primary, technical first-person guide voice) and `src/posts/nixos-stylix-polarity-toggle.md` (secondary, desktop and NixOS). The SEO post and the template-vs-custom post are thin and AI-ish: never use them as a voice model.

## How he speaks

- Earnest, slightly formal English. His grammar quirks are part of the voice: keep the odd join and the occasional awkward-but-clear phrasing. Do not polish into native-speaker corporate English.
- Concrete over adjectives: the stack, the constraint, the name, the number, the screenshot. "Built X for Y in 36 hours" beats "thrilled to announce an exciting journey".
- Long-form when the material earns it, and he explains mechanisms: context, what was built, what was hard, what is next.
- Grateful and specific after team wins: thank teammates, coaches, and organizers by name.
- One plain question when he wants something back ("Thoughts?", "Which do you prefer: A or B?"). Never a bait question, never a five-option soft poll.
- Building in public is matter-of-fact progress (domain bought, landing page up, feature shipped), checkmarks allowed, hype not.

## Shapes that work

1. Building-in-public or case study: what is being shipped, why it matters or what constrained it, concrete detail, soft close.
2. Hackathon recap: the win line, real scale facts, what the team built, his role, named thanks, optional human aside.
3. Feedback ask: show the work, one plain question, short context, no guilt and no retweet begging.
4. Reflective or discussion question: one honest question, sometimes with his own short take first, inviting answers rather than preaching.
5. Progress checklist: short factual status, checkmarks, "more soon".

## Coverlttr from the personal account

Soft and story-shaped, never brand copy:

- The honest framing: he spent a long stretch (about two years) building something so he would not have to grind cover-letter prep by hand.
- Early-access or "still working on it" register, an invitation to comment, not a hard sell.
- Prefer the parts that are real: tailored letters from CV plus role context, editable export, cost shown before generation, a PDF that survives an applicant tracking system instead of a claim that it beats one.
- Never: hire guarantees, "ATS-proof", mass-apply celebration, feature lists, "we" for the product unless he is talking about the small contributor team.
- Merre and other ventures only when the brief names them. Do not treat every work in progress as a product.

## Links

No URL in the post text. The site lives in the bio, and for a launch-shaped post the link goes in his own first reply (his pattern: screenshot post, then `coverlttr.com` with an honest note about what is not ready). If a draft depends on a link to make sense, rewrite the draft.

## Never

- Fake urgency, growth-hacker cadence, dunking, empty inspiration, LinkedIn thought-leader phrasing.
- Em dashes or en dashes. He has stated this repeatedly.
- Invented metrics, clients, awards, or event details. Names from his own recaps stay, and they stay spelled as he wrote them.
- Corporate polish that erases the slightly formal, imperfect English.
- Sounding like a generic agency blog or a thread-farming account.

## File: references/repo-cache.md

# Cached repo reads

Voice, messaging, and product files live in his GitHub repos. Reading them per run must not mean cloning or calling the GitHub API every time. One script owns that:

```bash
bash scripts/repo-file.sh <owner/repo> <branch> <path> [more paths...]
```

It prints each requested file to stdout, with a `===== <path>` header when more than one path is asked for. Any number of paths from the same repo in one call.

```bash
bash scripts/repo-file.sh enesbala5/portfolio main misc/TONE.md misc/PROFILE.md
bash scripts/repo-file.sh enesbala5/coverlttr dev docs/marketing/messaging.md
```

## Contract

- **Cache location:** `$REPO_CACHE_DIR`, default `~/.hermes/cache/repos/<owner>__<repo>`. One clone per repo, shared by every skill that reads it.
- **First call for a repo:** shallow clone (`--depth 1 --single-branch`) of the requested branch.
- **Later calls:** the script pulls only when the clone's last fetch is older than the TTL, default 21600 seconds (6 hours). Inside the window it reads the working tree straight from disk, no network.
- **Force a refresh:** `REPO_CACHE_TTL=0 bash scripts/repo-file.sh ...`. Use it when a doc is known to have just changed, not routinely.
- **Branch changes:** the clone records its branch in `.hermes-branch`; asking for a different branch re-clones rather than serving the wrong tree. Default branch of `coverlttr` is `master`, but the marketing docs are on `dev`, so the branch argument is not optional.
- **A failed pull is not a failure.** The script warns on stderr and serves the cached copy. Stale voice docs beat no voice docs, but mention it in the batch if a pull failed.
- **Locking:** an `mkdir` lock next to the clone serialises concurrent runs (the cron batch and an ad hoc ask can overlap). A lock older than five minutes is treated as stale and cleared.
- **Auth:** plain `https://github.com/...` clone, so the `gh` credential helper must be configured (`gh auth setup-git`). Without it a private repo fails and the script says so.
- **Missing paths** are reported on stderr at the end while the paths that do exist are still printed; exit code is 1 if any requested path was missing.

## Rules

1. Never `git clone` or `gh api repos/.../contents` in a session that has this script. Two paths to the same files is how the cache goes stale in one place and fresh in another.
2. Never edit the cache by hand. It is a read-only mirror of a branch; a `reset --hard` will discard anything written there.
3. `comment-response` uses the same script as `../draft-x-posts/scripts/repo-file.sh` (both live in the same skills directory), so the cache is shared and one pull serves both skills. If the sibling script is missing, fall back to `gh api repos/<repo>/contents/<path>?ref=<branch> -q .content | base64 -d` and say so in one line.
4. Durable facts belong in the repo, not in a skill. When something read this way is worth keeping, add it to the source file on the right branch.

## File: scripts/recent-work.sh

```bash
#!/usr/bin/env bash
# recent-work.sh - recent commits and merged PRs across Enes's repos.
#
# Usage: recent-work.sh [hours] [owner/repo ...]
#        recent-work.sh 36
#        recent-work.sh 72 enesbala5/portfolio enesbala5/merre
# Env:   REPO_CACHE_DIR  cache root used by repo-file.sh (fallback source)
#
# Build-in-public material for the X draft pipeline: newest first, one line per
# commit, then merged PRs. A repo with nothing in the window says so.

set -uo pipefail

hours="${1:-36}"
case "$hours" in ''|*[!0-9]*) echo "recent-work: hours must be a number" >&2; exit 2 ;; esac
shift || true

if [ "$#" -gt 0 ]; then
  repos=("$@")
else
  repos=(
    enesbala5/portfolio
    enesbala5/coverlttr
    enesbala5/merre
    enesbala5/lune
    enesbala5/config
  )
fi

cache_root="${REPO_CACHE_DIR:-$HOME/.hermes/cache/repos}"

# UTC cutoff, GNU date first, BSD/macOS fallback.
since_iso="$(date -u -d "-${hours} hours" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -u -v-"${hours}"H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" || true
if [ -z "$since_iso" ]; then
  echo "recent-work: cannot compute the cutoff date on this system" >&2
  exit 2
fi
since_day="$(printf '%s' "$since_iso" | cut -c1-10)"

echo "recent work, last ${hours}h (since ${since_iso})"
echo

have_gh=0
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  have_gh=1
fi

for repo in "${repos[@]}"; do
  echo "## $repo"
  printed=0

  if [ "$have_gh" -eq 1 ]; then
    commits="$(gh api "repos/$repo/commits?since=$since_iso&per_page=50" \
      --jq '.[] | select((.commit.message | split("\n")[0]) | test("^Merge ") | not)
                | "\(.commit.committer.date)  \(.sha[0:7])  \(.commit.message | split("\n")[0])"' 2>/dev/null)"
    if [ -n "$commits" ]; then
      printf '%s\n' "$commits"
      printed=1
    fi
  fi

  # Fallback: the local clone repo-file.sh keeps, when gh is missing or failed.
  if [ "$printed" -eq 0 ]; then
    clone="$cache_root/${repo//\//__}"
    if [ -d "$clone/.git" ]; then
      local_log="$(git -C "$clone" log --since="$since_iso" --no-merges \
        --pretty=format:'%cI  %h  %s' 2>/dev/null | head -20)"
      if [ -n "$local_log" ]; then
        printf '%s\n' "$local_log"
        printf '(from cached clone, may lag)\n'
        printed=1
      fi
    fi
  fi

  if [ "$printed" -eq 0 ]; then
    echo "(no commits in the window)"
  fi

  if [ "$have_gh" -eq 1 ]; then
    prs="$(gh pr list --repo "$repo" --state merged --limit 20 \
      --search "merged:>=$since_day" \
      --json number,title,mergedAt \
      --jq '.[] | "\(.mergedAt)  PR #\(.number)  \(.title)"' 2>/dev/null)"
    [ -n "$prs" ] && printf '%s\n' "$prs"
  fi

  echo
done
```

## File: scripts/repo-file.sh

```bash
#!/usr/bin/env bash
# repo-file.sh - print files from a cached clone of a GitHub repo.
#
# Usage: repo-file.sh <owner/repo> <branch> <path> [path...]
# Env:   REPO_CACHE_DIR  cache root   (default ~/.hermes/cache/repos)
#        REPO_CACHE_TTL  seconds      (default 21600 = 6h, 0 forces a pull)
#
# Clone once, pull at most once per TTL, read the rest from disk.
# A failed pull is not a failure: the cached copy is served with a warning.

set -uo pipefail

usage() {
  echo "usage: repo-file.sh <owner/repo> <branch> <path> [path...]" >&2
  exit 2
}

[ "$#" -ge 3 ] || usage

repo="$1"
branch="$2"
shift 2
paths=("$@")

cache_root="${REPO_CACHE_DIR:-$HOME/.hermes/cache/repos}"
ttl="${REPO_CACHE_TTL:-21600}"
dir="$cache_root/${repo//\//__}"
lock="$dir.lock"
marker="$dir/.hermes-last-fetch"
branchfile="$dir/.hermes-branch"
url="https://github.com/$repo.git"

log() { printf 'repo-file: %s\n' "$*" >&2; }

mkdir -p "$cache_root" || { log "cannot create $cache_root"; exit 1; }

# --- lock -------------------------------------------------------------------
waited=0
while ! mkdir "$lock" 2>/dev/null; do
  if [ -n "$(find "$lock" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then
    log "clearing stale lock $lock"
    rm -rf "$lock"
    continue
  fi
  waited=$((waited + 2))
  if [ "$waited" -ge 60 ]; then
    log "another run is holding $lock; refusing to wait longer"
    exit 1
  fi
  sleep 2
done
trap 'rm -rf "$lock"' EXIT

# --- clone / refresh --------------------------------------------------------
if [ ! -d "$dir/.git" ]; then
  log "cloning $repo@$branch into $dir"
  rm -rf "$dir"
  if ! git clone --quiet --depth 1 --single-branch --branch "$branch" "$url" "$dir"; then
    log "clone of $repo failed (private repo needs: gh auth setup-git)"
    exit 1
  fi
  printf '%s' "$branch" > "$branchfile"
  date +%s > "$marker"
elif [ "$(cat "$branchfile" 2>/dev/null)" != "$branch" ]; then
  log "cached clone is on branch '$(cat "$branchfile" 2>/dev/null)', wanted '$branch'; re-cloning"
  rm -rf "$dir"
  if ! git clone --quiet --depth 1 --single-branch --branch "$branch" "$url" "$dir"; then
    log "clone of $repo@$branch failed"
    exit 1
  fi
  printf '%s' "$branch" > "$branchfile"
  date +%s > "$marker"
else
  now=$(date +%s)
  last=$(cat "$marker" 2>/dev/null || echo 0)
  case "$last" in ''|*[!0-9]*) last=0 ;; esac
  if [ $((now - last)) -ge "$ttl" ]; then
    if git -C "$dir" fetch --quiet --depth 1 origin "$branch" \
       && git -C "$dir" reset --quiet --hard FETCH_HEAD; then
      log "pulled $repo@$branch"
      date +%s > "$marker"
    else
      log "pull of $repo@$branch failed; serving cached copy from $(date -r "$dir" '+%Y-%m-%d %H:%M' 2>/dev/null || echo 'an earlier fetch')"
    fi
  fi
fi

# --- read -------------------------------------------------------------------
missing=0
many=0
[ "${#paths[@]}" -gt 1 ] && many=1

for path in "${paths[@]}"; do
  target="$dir/$path"
  if [ -f "$target" ]; then
    [ "$many" -eq 1 ] && printf '===== %s\n' "$path"
    cat -- "$target"
    [ "$many" -eq 1 ] && printf '\n'
  else
    log "missing in $repo@$branch: $path"
    missing=$((missing + 1))
  fi
done

[ "$missing" -gt 0 ] && exit 1
exit 0
```
