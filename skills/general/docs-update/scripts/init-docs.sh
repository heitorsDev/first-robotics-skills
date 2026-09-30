#!/usr/bin/env bash
# Scaffolds docs/ on first run: section folders, state.json, map.json.
# Never overwrites an existing file.
#
# Usage:
#   init-docs.sh --source master --docs-branch docs --language pt-BR

set -uo pipefail

SOURCE=""; DOCS_BRANCH="docs"; LANG_CODE="en"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) SOURCE="${2:-}"; shift 2 ;;
    --docs-branch) DOCS_BRANCH="${2:-docs}"; shift 2 ;;
    --language) LANG_CODE="${2:-en}"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "init-docs.sh: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repository." >&2; exit 1; }
cd "$(git rev-parse --show-toplevel)" || exit 1

if [ -z "$SOURCE" ]; then
  for candidate in main master; do
    if git show-ref --verify --quiet "refs/heads/${candidate}"; then SOURCE="$candidate"; break; fi
  done
fi
[ -n "$SOURCE" ] || { echo "Could not resolve the source branch. Pass --source." >&2; exit 1; }

SECTIONS="00-overview 10-components 20-guides 30-reference 40-operations"
for section in $SECTIONS; do
  mkdir -p "docs/${section}"
done
mkdir -p docs/.docsync

created=()
write_if_absent() { # write_if_absent <path>  (body on stdin)
  if [ -e "$1" ]; then cat >/dev/null; return 0; fi
  cat > "$1" || return 1
  created+=("$1")
}

for section in $SECTIONS; do
  title="$(printf '%s' "${section#*-}" | tr '-' ' ')"
  write_if_absent "docs/${section}/README.md" <<EOF
# ${title}

<!-- docs-update:index-start -->
_Empty section._
<!-- docs-update:index-end -->
EOF
done

write_if_absent docs/index.md <<'EOF'
# Documentation

<!-- docs-update:index-start -->
_Not generated yet. Run the docs-update skill._
<!-- docs-update:index-end -->
EOF

write_if_absent docs/CHANGELOG.md <<'EOF'
# Documentation changelog

Newest first. One entry per documentation sync.
EOF

write_if_absent docs/.docsync/state.json <<EOF
{
  "source_branch": "${SOURCE}",
  "docs_branch": "${DOCS_BRANCH}",
  "last_synced_sha": "",
  "last_synced_at": "",
  "language": "${LANG_CODE}",
  "ignore": []
}
EOF

write_if_absent docs/.docsync/map.json <<'EOF'
{
  "routes": [],
  "fallback": "00-overview/architecture.md"
}
EOF

echo "### INIT"
echo "source branch : ${SOURCE}"
echo "docs branch   : ${DOCS_BRANCH}"
echo "language      : ${LANG_CODE}"
echo
if [ "${#created[@]}" -eq 0 ]; then
  echo "### CREATED: nothing (docs/ already scaffolded)"
else
  echo "### CREATED"
  printf '  %s\n' "${created[@]}"
fi
