#!/usr/bin/env bash
# Usage: bump-version.sh <current-semver> <patch|minor|major>
# Prints the next semver. Exit 1 on a malformed version or bump type.
set -euo pipefail

current="${1:-}"
bump_type="${2:-}"

if [[ ! "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "error: malformed version '$current'" >&2
  exit 1
fi

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"

case "$bump_type" in
  patch) echo "$major.$minor.$((patch + 1))" ;;
  minor) echo "$major.$((minor + 1)).0" ;;
  major) echo "$((major + 1)).0.0" ;;
  *) echo "error: bump type must be patch, minor or major (got '$bump_type')" >&2; exit 1 ;;
esac
