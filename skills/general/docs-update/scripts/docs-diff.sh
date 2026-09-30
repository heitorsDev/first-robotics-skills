#!/usr/bin/env bash
# Prints the source changes that still need to be documented.
#
# Usage:
#   docs-diff.sh                      # state.last_synced_sha .. source HEAD
#   docs-diff.sh --from <sha> --to <ref>
#   docs-diff.sh --context 10
#   docs-diff.sh --files-only         # skip the patch body
#
# Output: FROM/TO header, commit log, --stat, name-status, unified patch.
# When no last_synced_sha is recorded it switches to bootstrap mode and lists
# the tracked files instead of a diff.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=state.sh
. "${SCRIPT_DIR}/state.sh"

FROM=""; TO=""; CONTEXT="${DIFF_CONTEXT:-8}"; FILES_ONLY=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --from) FROM="${2:-}"; shift 2 ;;
    --to)   TO="${2:-}";   shift 2 ;;
    --context) CONTEXT="${2:-8}"; shift 2 ;;
    --files-only) FILES_ONLY=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "docs-diff.sh: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repository." >&2; exit 1; }
cd "$(git rev-parse --show-toplevel)" || exit 1

[ -n "$TO" ] || TO="$(state_get source_branch master)"
git rev-parse --verify --quiet "$TO" >/dev/null || { echo "Unknown ref '${TO}'." >&2; exit 1; }
TO_SHA="$(git rev-parse "$TO")"

[ -n "$FROM" ] || FROM="$(state_get last_synced_sha)"

# Paths that never deserve a doc update. Defaults + state.ignore.
EXCLUDES=(
  ':(exclude)docs/*'
  ':(exclude)build/*' ':(exclude)dist/*' ':(exclude)out/*' ':(exclude)target/*'
  ':(exclude)bin/*' ':(exclude).gradle/*' ':(exclude)node_modules/*' ':(exclude)vendor/*'
  ':(exclude)*.lock' ':(exclude)*-lock.json' ':(exclude)*.min.js'
  ':(exclude)*.png' ':(exclude)*.jpg' ':(exclude)*.jpeg' ':(exclude)*.gif'
  ':(exclude)*.pdf' ':(exclude)*.zip' ':(exclude)*.jar'
)
while IFS= read -r pattern; do
  [ -n "$pattern" ] && EXCLUDES+=(":(exclude)${pattern}")
done < <(state_list ignore)

# --- bootstrap: nothing documented yet ---------------------------------------
if [ -z "$FROM" ]; then
  echo "### MODE: bootstrap (no last_synced_sha in state)"
  echo "### TO: ${TO} (${TO_SHA})"
  echo
  echo "### TRACKED FILES"
  # Diff against the empty tree: git ls-tree does not honour :(exclude) pathspecs.
  EMPTY_TREE="$(git hash-object -t tree /dev/null)"
  git diff --name-only "$EMPTY_TREE" "$TO_SHA" -- . "${EXCLUDES[@]}"
  exit 0
fi

if ! git rev-parse --verify --quiet "${FROM}^{commit}" >/dev/null; then
  echo "last_synced_sha '${FROM}' is not a commit in this repository." >&2
  echo "Fix docs/.docsync/state.json or pass --from explicitly." >&2
  exit 1
fi
FROM_SHA="$(git rev-parse "$FROM")"

echo "### MODE: incremental"
echo "### FROM: ${FROM_SHA}"
echo "### TO:   ${TO} (${TO_SHA})"
echo

if [ "$FROM_SHA" = "$TO_SHA" ]; then
  echo "### RESULT: nothing new to document"
  exit 0
fi

echo "### COMMITS"
git log --no-merges --pretty='  %h %s (%an)' "${FROM_SHA}..${TO_SHA}"
echo

echo "### FILES"
git diff --stat "${FROM_SHA}..${TO_SHA}" -- . "${EXCLUDES[@]}"
echo

echo "### STATUS"
git diff --name-status "${FROM_SHA}..${TO_SHA}" -- . "${EXCLUDES[@]}"

if [ "$FILES_ONLY" = 1 ]; then exit 0; fi

echo
echo "### DIFF"
git diff "-U${CONTEXT}" "${FROM_SHA}..${TO_SHA}" -- . "${EXCLUDES[@]}"
