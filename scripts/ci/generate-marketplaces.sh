#!/usr/bin/env bash
# Regenerates the .claude-plugin wrapper for every skill and the three
# scope marketplaces (general, frc, ftc). Plain skills/<scope>/<name>/ dirs
# are canonical; everything this script writes is generated, never hand-edited.
#
# Usage: scripts/ci/generate-marketplaces.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
# shellcheck source=./lib.sh
source "$REPO_ROOT/scripts/ci/lib.sh"

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }

skill_version() {
  # latest tag <name>@X.Y.Z, or 0.1.0 if this skill has never been released
  local name="$1"
  git tag -l "${name}@*" --sort=-v:refname | head -n1 | sed "s/^${name}@//" \
    || true
}

write_plugin_json() {
  local scope="$1" dir="$2"
  local name fm desc version
  name="$(basename "$dir")"
  fm="$(extract_frontmatter "$dir/SKILL.md")"
  desc="$(fm_value "$fm" "description")"
  version="$(skill_version "$name")"
  [ -n "$version" ] || version="0.1.0"

  mkdir -p "$dir/.claude-plugin"
  jq -n \
    --arg name "$name" \
    --arg description "$desc" \
    --arg version "$version" \
    '{name: $name, description: $description, version: $version, author: {name: "FIRST Robotics Skills contributors"}}' \
    > "$dir/.claude-plugin/plugin.json"

  echo "${scope}|${name}|${dir}|${desc}"
}

general_entries=()
frc_entries=()
ftc_entries=()

collect() {
  local scope="$1" dir="$2"
  local line
  line="$(write_plugin_json "$scope" "$dir")"
  case "$scope" in
    general) general_entries+=("$line") ;;
    frc)     frc_entries+=("$line") ;;
    ftc)     ftc_entries+=("$line") ;;
  esac
}

each_skill_dir collect

write_marketplace() {
  # $1 = scope dir name (general|frc|ftc), rest = entry lines "scope|name|dir|desc"
  local scope="$1"; shift
  local out="skills/$scope/.claude-plugin/marketplace.json"
  mkdir -p "skills/$scope/.claude-plugin"

  local plugins_json="[]"
  local entry scope_ name dir desc source
  for entry in "$@"; do
    [ -n "$entry" ] || continue
    IFS='|' read -r scope_ name dir desc <<< "$entry"
    source="../../${dir#skills/}"
    plugins_json="$(echo "$plugins_json" | jq \
      --arg name "$name" --arg source "$source" --arg description "$desc" \
      '. + [{name: $name, source: $source, description: $description}]')"
  done

  jq -n \
    --arg name "first-robotics-skills-$scope" \
    --arg owner "heitorsDev" \
    --argjson plugins "$plugins_json" \
    '{name: $name, owner: {name: $owner}, plugins: $plugins}' \
    > "$out"
  echo "wrote $out ($(echo "$plugins_json" | jq length) plugins)"
}

write_marketplace general "${general_entries[@]}"
write_marketplace frc "${general_entries[@]}" "${frc_entries[@]}"
write_marketplace ftc "${general_entries[@]}" "${ftc_entries[@]}"
