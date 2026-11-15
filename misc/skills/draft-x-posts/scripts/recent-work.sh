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
