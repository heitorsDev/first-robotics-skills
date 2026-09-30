#!/usr/bin/env bash
# Resolve and print the diff to review.
#
# Usage:
#   get-diff.sh                 # figures it out on its own (PR > branch > working tree)
#   get-diff.sh <base> <head>   # explicit, e.g. get-diff.sh origin/main HEAD
#
# Output: "### SOURCE: ..." header + "### FILES" (--stat) + "### DIFF" (unified patch).
# Exits 1 with a message on stderr if there's nothing to review.

set -uo pipefail

CONTEXT_LINES="${DIFF_CONTEXT:-8}"
# Skip generated/binary files that just add noise to the review.
EXCLUDES=(
  ':(exclude)gradle/wrapper/gradle-wrapper.jar'
  ':(exclude)*.png' ':(exclude)*.jpg' ':(exclude)*.pdf'
  ':(exclude)*.apk' ':(exclude)*.iml'
  ':(exclude)build/*' ':(exclude)*/build/*' ':(exclude).gradle/*' ':(exclude).idea/*'
)

emit() {
  local source="$1"; shift
  echo "### SOURCE: ${source}"
  echo
  echo "### FILES"
  git diff --stat "$@" -- . "${EXCLUDES[@]}"
  echo
  echo "### DIFF"
  git diff "-U${CONTEXT_LINES}" "$@" -- . "${EXCLUDES[@]}"
}

# --- 1. explicit base/head -----------------------------------------------
if [ "$#" -ge 2 ]; then
  emit "explicit: $1...$2" "$1...$2"
  exit 0
fi

# --- 2. Pull Request (CI case) --------------------------------------------
# Discover the PR number from an env var or from GITHUB_REF (refs/pull/123/merge).
PR="${PR_NUMBER:-}"
if [ -z "$PR" ] && [ -n "${GITHUB_REF:-}" ]; then
  case "$GITHUB_REF" in
    refs/pull/*) PR="$(printf '%s' "$GITHUB_REF" | cut -d/ -f3)" ;;
  esac
fi
if [ -z "$PR" ] && [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -r "${GITHUB_EVENT_PATH}" ]; then
  PR="$(grep -o '"number"[[:space:]]*:[[:space:]]*[0-9]*' "$GITHUB_EVENT_PATH" \
        | head -1 | grep -o '[0-9]*$' || true)"
fi

if [ -n "$PR" ] && command -v gh >/dev/null 2>&1; then
  if DIFF="$(gh pr diff "$PR" --patch 2>/dev/null)" && [ -n "$DIFF" ]; then
    echo "### SOURCE: Pull Request #${PR} (gh pr diff)"
    echo
    echo "### FILES"
    gh pr view "$PR" --json files \
      --jq '.files[] | "\(.path)  +\(.additions) -\(.deletions)"' 2>/dev/null \
      || printf '%s\n' "$DIFF" | grep '^+++ b/' | sed 's|^+++ b/|  |'
    echo
    echo "### DIFF"
    printf '%s\n' "$DIFF"
    exit 0
  fi
  echo "warning: 'gh pr diff $PR' failed (missing GH_TOKEN?), falling back to local git" >&2
fi

# --- 3. local branch vs. remote base ---------------------------------------
BASE=""
for cand in origin/main origin/master main master; do
  if git rev-parse --verify --quiet "$cand" >/dev/null; then BASE="$cand"; break; fi
done

if [ -n "$BASE" ]; then
  MERGE_BASE="$(git merge-base "$BASE" HEAD 2>/dev/null || true)"
  if [ -n "$MERGE_BASE" ] && [ "$(git rev-parse HEAD)" != "$MERGE_BASE" ]; then
    emit "branch $(git rev-parse --abbrev-ref HEAD) vs ${BASE} (merge-base ${MERGE_BASE:0:8})" \
      "${MERGE_BASE}...HEAD"
    exit 0
  fi
fi

# --- 4. uncommitted work ----------------------------------------------------
if [ -n "$(git status --porcelain)" ]; then
  emit "uncommitted changes (git diff HEAD)" "HEAD"
  exit 0
fi

echo "error: no diff found. Pass base and head explicitly:" >&2
echo "  bash $0 origin/main HEAD" >&2
exit 1
