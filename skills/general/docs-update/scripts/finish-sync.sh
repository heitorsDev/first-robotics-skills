#!/usr/bin/env bash
# Records a completed documentation sync: bumps state.json, then commits docs/.
#
# Usage:
#   finish-sync.sh --sha <source-head-sha> [--message "docs: ..."] [--no-commit]
#
# Never pushes. Prints the push command for the human to run.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=state.sh
. "${SCRIPT_DIR}/state.sh"

SHA=""; MESSAGE=""; COMMIT=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    --sha) SHA="${2:-}"; shift 2 ;;
    --message) MESSAGE="${2:-}"; shift 2 ;;
    --no-commit) COMMIT=0; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "finish-sync.sh: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repository." >&2; exit 1; }
cd "$(git rev-parse --show-toplevel)" || exit 1
[ -f "$STATE_FILE" ] || { echo "Missing ${STATE_FILE}. Run init-docs.sh first." >&2; exit 1; }

SOURCE_BRANCH="$(state_get source_branch master)"
[ -n "$SHA" ] || SHA="$(git rev-parse "$SOURCE_BRANCH" 2>/dev/null)"
[ -n "$SHA" ] || { echo "Could not resolve the source SHA. Pass --sha." >&2; exit 1; }
SHA="$(git rev-parse "$SHA")"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if command -v python3 >/dev/null 2>&1; then
  python3 -c '
import json, sys
path, sha, now = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as fh:
    state = json.load(fh)
state["last_synced_sha"] = sha
state["last_synced_at"] = now
with open(path, "w") as fh:
    json.dump(state, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
' "$STATE_FILE" "$SHA" "$NOW" || { echo "Failed to update ${STATE_FILE}." >&2; exit 1; }
else
  # Fallback: in-place field replacement, keeps unknown keys untouched.
  tmp="${STATE_FILE}.tmp.$$"
  sed -e "s#\"last_synced_sha\"[[:space:]]*:[[:space:]]*\"[^\"]*\"#\"last_synced_sha\": \"${SHA}\"#" \
      -e "s#\"last_synced_at\"[[:space:]]*:[[:space:]]*\"[^\"]*\"#\"last_synced_at\": \"${NOW}\"#" \
      "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
fi

echo "### STATE"
echo "last_synced_sha : ${SHA}"
echo "last_synced_at  : ${NOW}"
echo

DOCS_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

if [ "$COMMIT" = 0 ]; then
  echo "### COMMIT: skipped (--no-commit)"
  exit 0
fi

git add docs
if git diff --cached --quiet; then
  echo "### COMMIT: nothing staged under docs/"
  exit 0
fi

[ -n "$MESSAGE" ] || MESSAGE="docs: sync documentation with ${SOURCE_BRANCH}@$(git rev-parse --short "$SHA")"
git commit -q -m "$MESSAGE" || { echo "git commit failed." >&2; exit 1; }

echo "### COMMIT"
git show --stat --oneline HEAD | sed 's/^/  /'
echo
echo "### NEXT STEP (run it yourself)"
echo "  git push origin ${DOCS_BRANCH}"
