#!/usr/bin/env bash
# Scaffold a new skill from skills/_template/ into skills/<scope>/<name>/.
#
# Usage: scripts/new-skill.sh <general|frc|ftc> <skill-name>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPE="${1:-}"
NAME="${2:-}"

usage() {
  echo "usage: $(basename "$0") <general|frc|ftc> <skill-name>" >&2
  exit 1
}

[ -n "$SCOPE" ] && [ -n "$NAME" ] || usage

case "$SCOPE" in
  general|frc|ftc) ;;
  *) echo "error: scope must be one of general, frc, ftc (got '$SCOPE')" >&2; exit 1 ;;
esac

if [[ ! "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "error: skill name must be lower-kebab-case (got '$NAME')" >&2
  exit 1
fi

if [ "$SCOPE" != "general" ] && [[ "$NAME" != "$SCOPE"-* ]]; then
  echo "error: skills under skills/$SCOPE/ must be prefixed '$SCOPE-' (e.g. $SCOPE-$NAME)" >&2
  exit 1
fi

DEST="$REPO_ROOT/skills/$SCOPE/$NAME"
if [ -e "$DEST" ]; then
  echo "error: $DEST already exists" >&2
  exit 1
fi

cp -r "$REPO_ROOT/skills/_template" "$DEST"

TITLE="$(echo "$NAME" | sed -E 's/(^|-)([a-z])/\1\U\2/g; s/-/ /g')"
sed -i \
  -e "s/__SKILL_NAME__/$NAME/g" \
  -e "s/__SKILL_TITLE__/$TITLE/g" \
  "$DEST/SKILL.md"

echo "created skills/$SCOPE/$NAME/"
echo "next: write SKILL.md, then open a PR on a branch named fix/... feat/... or release/..."
