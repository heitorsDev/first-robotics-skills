#!/usr/bin/env bash
# The release bump a branch asks for, from its prefix alone.
# Mirrors heitorsdev-template's fix/feat/release convention.
#
# Usage: bump-type-from-branch.sh <branch-name>
# Prints: patch | minor | major
# Exit 1, no output, for any other prefix (that branch must not release).
set -euo pipefail

branch="${1:-}"

case "$branch" in
  fix/*)     echo "patch" ;;
  feat/*)    echo "minor" ;;
  release/*) echo "major" ;;
  *)         exit 1 ;;
esac
