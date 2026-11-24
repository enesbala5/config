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
