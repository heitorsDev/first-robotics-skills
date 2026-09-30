#!/usr/bin/env bash
# Shared helpers for the CI scripts. Sourced, not executed.

extract_frontmatter() {
  # prints the YAML frontmatter block (without the --- fences) of $1
  awk '
    NR==1 && $0!="---" { exit }
    NR==1 { infm=1; next }
    infm && $0=="---" { exit }
    infm { print }
  ' "$1"
}

fm_value() {
  # $1 = frontmatter text, $2 = key -> prints the scalar value, trimmed
  echo "$1" | grep -E "^${2}:" | head -n1 | sed -E "s/^${2}:[[:space:]]*//; s/[[:space:]]+\$//"
}

each_skill_dir() {
  # calls "$1" <scope> <dir> for every real skill under skills/*/*
  local callback="$1"
  local scope dir name
  for scope in general frc ftc; do
    [ -d "skills/$scope" ] || continue
    for dir in "skills/$scope"/*/; do
      [ -d "$dir" ] || continue
      name="$(basename "$dir")"
      [ "$name" = "_template" ] && continue
      "$callback" "$scope" "${dir%/}"
    done
  done
}
