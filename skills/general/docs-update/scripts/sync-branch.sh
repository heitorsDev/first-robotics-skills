#!/usr/bin/env bash
# Puts the repo on the docs branch, up to date with the source branch.
#
# Usage:
#   sync-branch.sh                                  # resolve everything from state/remote
#   sync-branch.sh --source master --docs docs
#   sync-branch.sh --no-fetch
#
# Exit codes: 0 merged (or already current) | 1 precondition failed | 2 merge conflict.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=state.sh
. "${SCRIPT_DIR}/state.sh"

SOURCE=""; DOCS=""; FETCH=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --docs)   DOCS="${2:-}";   shift 2 ;;
    --no-fetch) FETCH=0; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "sync-branch.sh: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repository." >&2; exit 1; }
cd "$(git rev-parse --show-toplevel)" || exit 1

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is dirty. Commit or stash before syncing docs." >&2
  git status --short >&2
  exit 1
fi

ORIGINAL_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# --- resolve source branch ---------------------------------------------------
[ -n "$SOURCE" ] || SOURCE="$(state_get source_branch)"
if [ -z "$SOURCE" ]; then
  SOURCE="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
fi
if [ -z "$SOURCE" ]; then
  for candidate in main master; do
    if git show-ref --verify --quiet "refs/heads/${candidate}"; then SOURCE="$candidate"; break; fi
  done
fi
[ -n "$SOURCE" ] || { echo "Could not resolve the source branch. Pass --source." >&2; exit 1; }

# --- resolve docs branch -----------------------------------------------------
[ -n "$DOCS" ] || DOCS="$(state_get docs_branch docs)"

HAS_REMOTE=0
git remote get-url origin >/dev/null 2>&1 && HAS_REMOTE=1
if [ "$FETCH" = 1 ] && [ "$HAS_REMOTE" = 1 ]; then
  git fetch origin --quiet || echo "warning: git fetch failed, continuing with local refs" >&2
fi

# CI checkouts often leave the source branch only as a remote-tracking ref.
if ! git show-ref --verify --quiet "refs/heads/${SOURCE}"; then
  if git show-ref --verify --quiet "refs/remotes/origin/${SOURCE}"; then
    git branch --quiet "$SOURCE" "origin/${SOURCE}" || exit 1
  else
    echo "Source branch '${SOURCE}' exists neither locally nor on origin." >&2
    exit 1
  fi
fi

CREATED=0
if ! git show-ref --verify --quiet "refs/heads/${DOCS}"; then
  if [ "$HAS_REMOTE" = 1 ] && git show-ref --verify --quiet "refs/remotes/origin/${DOCS}"; then
    git checkout -q -b "$DOCS" --track "origin/${DOCS}" || exit 1
  else
    git checkout -q -b "$DOCS" "$SOURCE" || exit 1
    CREATED=1
  fi
else
  git checkout -q "$DOCS" || exit 1
fi

SOURCE_SHA="$(git rev-parse "$SOURCE")"

echo "### DOCS SYNC"
echo "original branch : ${ORIGINAL_BRANCH}"
echo "source branch   : ${SOURCE} (${SOURCE_SHA})"
echo "docs branch     : ${DOCS}$([ "$CREATED" = 1 ] && echo ' (created from source)')"
echo

# --- merge -------------------------------------------------------------------
if [ "$CREATED" = 1 ] || git merge-base --is-ancestor "$SOURCE" HEAD; then
  echo "### MERGE: already up to date with ${SOURCE}"
else
  # Kept in a variable rather than a temp file: writing outside the repository
  # trips the sandbox of agents that run this, and a blocked write looks like a hang.
  if merge_output="$(git merge --no-edit "$SOURCE" 2>&1)"; then
    echo "### MERGE: ok"
    printf '%s\n' "$merge_output" | sed 's/^/  /'
  else
    echo "### MERGE: CONFLICT"
    printf '%s\n' "$merge_output" | sed 's/^/  /'
    echo
    echo "Conflicting paths:"
    git diff --name-only --diff-filter=U | sed 's/^/  /'
    exit 2
  fi
fi

echo
echo "### SOURCE HEAD"
echo "$SOURCE_SHA"
