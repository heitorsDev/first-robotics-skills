#!/usr/bin/env bash
# Deterministic structure/format gate for every skill PR.
# Checks only shape and syntax — never content quality; that's the two
# human reviewers' call.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
# shellcheck source=./lib.sh
source "$REPO_ROOT/scripts/ci/lib.sh"

fail=0
declare -A seen_names

err() {
  echo "FAIL: $1" >&2
  fail=1
}

for scope in general frc ftc; do
  scope_dir="skills/$scope"
  [ -d "$scope_dir" ] || continue

  for dir in "$scope_dir"/*/; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    [ "$name" = "_template" ] && continue
    [[ "$name" == .* ]] && continue

    skill_md="$dir/SKILL.md"
    if [ ! -f "$skill_md" ]; then
      err "$dir missing SKILL.md"
      continue
    fi

    if [ "$(head -n1 "$skill_md")" != "---" ]; then
      err "$skill_md: does not start with a --- frontmatter fence"
      continue
    fi

    fm="$(extract_frontmatter "$skill_md")"

    fm_name="$(fm_value "$fm" "name")"
    fm_desc="$(fm_value "$fm" "description")"

    [ -n "$fm_name" ] || err "$skill_md: frontmatter missing 'name'"
    [ -n "$fm_desc" ] || err "$skill_md: frontmatter missing 'description'"

    if [ -n "$fm_name" ] && [ "$fm_name" != "$name" ]; then
      err "$skill_md: frontmatter name '$fm_name' does not match folder name '$name'"
    fi

    if [ "$scope" != "general" ] && [[ "$name" != "$scope"-* ]]; then
      err "$dir: skills under skills/$scope/ must be prefixed '$scope-'"
    fi

    if [ -n "$fm_name" ]; then
      if [ -n "${seen_names[$fm_name]:-}" ]; then
        err "skill name '$fm_name' is used more than once (${seen_names[$fm_name]} and $dir)"
      else
        seen_names[$fm_name]="$dir"
      fi
    fi

    if [ -d "$dir/scripts" ]; then
      for script in "$dir"/scripts/*.sh; do
        [ -e "$script" ] || continue
        [ -x "$script" ] || err "$script: not executable (chmod +x)"
      done
    fi
  done
done

if [ "$fail" -eq 0 ]; then
  echo "OK: all skills pass structural validation"
fi
exit "$fail"
